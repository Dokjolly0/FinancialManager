// Package backup implements the worker's off-site backup job (plan.md
// section 20.4/21.10): a PostgreSQL dump plus an archive of the media
// bucket, encrypted with a passphrase and uploaded to Google Drive.
package backup

import (
	"context"
	"errors"
	"fmt"
	"os"
	"path/filepath"
	"time"

	"financial-manager-backend/internal/platform/clock"
)

// Config is the backup job's tuning, mirrored from config.Config.
type Config struct {
	DatabaseURL     string
	EncryptionKey   string
	Interval        time.Duration
	RetentionDays   int
	RetentionMonths int
	IncludeMedia    bool
}

// Deps are the Service's collaborators. Media may be nil when
// Config.IncludeMedia is false; Dump defaults to DumpDatabase.
type Deps struct {
	Config Config
	Dest   Destination
	Media  objectSource
	Clock  clock.Clock
	Dump   func(ctx context.Context, databaseURL, path string) error
}

// Service runs backups: dump + encrypt + upload the database, archive +
// encrypt + rotate the media bucket, then prune expired dumps.
type Service struct {
	cfg   Config
	dest  Destination
	media objectSource
	clock clock.Clock
	dump  func(ctx context.Context, databaseURL, path string) error
}

func NewService(d Deps) *Service {
	dump := d.Dump
	if dump == nil {
		dump = DumpDatabase
	}
	return &Service{cfg: d.Config, dest: d.Dest, media: d.Media, clock: d.Clock, dump: dump}
}

// Result describes a RunIfDue call, for the job's log line and metrics.
type Result struct {
	// Ran is false when the latest backup was still fresh.
	Ran bool
	// LastBackupAt is the newest database dump at the destination after
	// the call (zero if there is none).
	LastBackupAt time.Time

	DBDump       RemoteFile
	MediaArchive RemoteFile
	MediaStats   ArchiveStats
	Pruned       int
	Duration     time.Duration
}

// RunIfDue runs a backup unless the newest database dump at the destination
// is younger than the configured interval. Deriving "due" from the
// destination rather than from in-memory state means a worker restart
// doesn't trigger an extra backup, and a missed day is caught up on the
// next check.
func (s *Service) RunIfDue(ctx context.Context) (Result, error) {
	files, err := s.dest.List(ctx)
	if err != nil {
		return Result{}, err
	}
	if dumps := dbDumps(files); len(dumps) > 0 {
		last := dumps[0].at
		if s.clock.Now().Sub(last) < s.cfg.Interval-dueSlack(s.cfg.Interval) {
			return Result{LastBackupAt: last}, nil
		}
	}
	return s.Run(ctx)
}

// dueSlack lets a check that fires a moment before the interval elapses
// still count as due. Without it, an hourly check against a 24h interval
// would push every backup an hour later than the previous one.
func dueSlack(interval time.Duration) time.Duration {
	return min(5*time.Minute, interval/10)
}

// Run performs a backup unconditionally. The database is uploaded before
// the media archive is even built, so a media failure never costs the
// (far more important) database backup.
func (s *Service) Run(ctx context.Context) (Result, error) {
	start := s.clock.Now()
	res := Result{Ran: true}

	dir, err := os.MkdirTemp("", "fm-backup-*")
	if err != nil {
		return res, err
	}
	// Plaintext dumps only ever exist in this directory, and only until
	// they're encrypted.
	defer os.RemoveAll(dir)

	dbPath, err := s.encrypted(dir, "postgres.dump", func(path string) error {
		return s.dump(ctx, s.cfg.DatabaseURL, path)
	})
	if err != nil {
		return res, fmt.Errorf("database dump: %w", err)
	}
	if res.DBDump, err = s.dest.Upload(ctx, dbDumpName(start), dbPath); err != nil {
		return res, fmt.Errorf("upload database dump: %w", err)
	}
	res.LastBackupAt = start

	if s.cfg.IncludeMedia {
		mediaPath, err := s.encrypted(dir, "media.tar.gz", func(path string) error {
			stats, err := ArchiveMedia(ctx, s.media, path)
			res.MediaStats = stats
			return err
		})
		if err != nil {
			return res, fmt.Errorf("media archive: %w", err)
		}
		if res.MediaArchive, err = rotateMedia(ctx, s.dest, mediaPath); err != nil {
			return res, fmt.Errorf("upload media archive: %w", err)
		}
	}

	if res.Pruned, err = s.prune(ctx); err != nil {
		return res, fmt.Errorf("prune expired dumps: %w", err)
	}
	res.Duration = s.clock.Now().Sub(start)
	return res, nil
}

// encrypted has produce write a plaintext file in dir, encrypts it and
// removes the plaintext, returning the encrypted file's path.
func (s *Service) encrypted(dir, name string, produce func(path string) error) (string, error) {
	plain := filepath.Join(dir, name)
	if err := produce(plain); err != nil {
		return "", err
	}
	enc := plain + encryptedExt
	err := EncryptFile(enc, plain, s.cfg.EncryptionKey)
	return enc, errors.Join(err, os.Remove(plain))
}

func (s *Service) prune(ctx context.Context) (int, error) {
	files, err := s.dest.List(ctx)
	if err != nil {
		return 0, err
	}
	pruned := 0
	for _, f := range selectExpired(files, s.clock.Now(), s.cfg.RetentionDays, s.cfg.RetentionMonths) {
		if err := s.dest.Delete(ctx, f.ID); err != nil {
			return pruned, err
		}
		pruned++
	}
	return pruned, nil
}
