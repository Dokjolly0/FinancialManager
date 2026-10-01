package backup

import (
	"archive/tar"
	"compress/gzip"
	"context"
	"fmt"
	"io"
	"os"
	"time"

	"financial-manager-backend/internal/platform/storage"
)

// objectSource is the slice of the object store the media archive needs.
// storage.MinIOStore satisfies it; List is deliberately not part of
// storage.Store (see its doc comment).
type objectSource interface {
	List(ctx context.Context, fn func(storage.ObjectInfo) error) error
	Get(ctx context.Context, key string) (io.ReadCloser, error)
}

var _ objectSource = (*storage.MinIOStore)(nil)

// ArchiveStats summarizes an archived bucket for the job's log line.
type ArchiveStats struct {
	Objects int
	Bytes   int64
}

// ArchiveMedia writes every object in src to path as a tar.gz whose entry
// names are the object keys — the same layout `mc mirror` produces in
// scripts/backup.sh, so restoring is "extract, then mc mirror back".
func ArchiveMedia(ctx context.Context, src objectSource, path string) (ArchiveStats, error) {
	f, err := os.Create(path)
	if err != nil {
		return ArchiveStats{}, err
	}
	gz := gzip.NewWriter(f)
	tw := tar.NewWriter(gz)

	var stats ArchiveStats
	now := time.Now()
	walkErr := src.List(ctx, func(obj storage.ObjectInfo) error {
		if err := tw.WriteHeader(&tar.Header{
			Name:    obj.Key,
			Mode:    0o644,
			Size:    obj.SizeBytes,
			ModTime: now,
		}); err != nil {
			return err
		}
		body, err := src.Get(ctx, obj.Key)
		if err != nil {
			return fmt.Errorf("get %s: %w", obj.Key, err)
		}
		n, err := io.Copy(tw, body)
		_ = body.Close()
		if err != nil {
			return fmt.Errorf("copy %s: %w", obj.Key, err)
		}
		stats.Objects++
		stats.Bytes += n
		return nil
	})

	// Close every layer even on failure so the file handle is released;
	// the first error wins.
	errs := []error{walkErr, tw.Close(), gz.Close(), f.Close()}
	for _, err := range errs {
		if err != nil {
			return ArchiveStats{}, fmt.Errorf("archive media: %w", err)
		}
	}
	return stats, nil
}
