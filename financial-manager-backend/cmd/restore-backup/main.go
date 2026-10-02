// Command restore-backup turns an encrypted backup (as uploaded to Google
// Drive by the worker, or written by scripts/backup.sh) back into a full
// PostgreSQL database on your own machine, ready to browse with DataGrip,
// psql or any other client.
//
// Into a disposable Docker container (postgres:16-alpine on 127.0.0.1):
//
//	go run ./cmd/restore-backup -dump fm-20261001T154350Z-postgres.dump.enc
//
// Or into a PostgreSQL server installed on the machine, so the database
// stays available without Docker running:
//
//	go run ./cmd/restore-backup -dump <file> -target postgres://postgres@localhost:5432
//
// It decrypts the dump (no openssl needed), restores it, prints the row
// count of every table and the connection details. With -media it also
// decrypts and extracts the media archive into a folder.
//
// The passphrase is read from BACKUP_ENCRYPTION_KEY or, if unset, prompted
// for without echo.
//
// This is for inspecting and verifying backups locally. To restore onto the
// server's own stack, use scripts/restore.sh.
package main

import (
	"context"
	"errors"
	"flag"
	"fmt"
	"os"
	"os/signal"
	"path/filepath"
	"regexp"

	"golang.org/x/term"

	"financial-manager-backend/internal/backup"
)

type options struct {
	dump     string
	media    string
	mediaDir string
	db       string
	replace  bool

	// Docker target.
	name     string
	port     int
	password string

	// Local server target.
	target string
	pgBin  string
}

func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, "error:", err)
		os.Exit(1)
	}
}

func run() error {
	var o options
	flag.StringVar(&o.dump, "dump", "", "database backup to restore (fm-...-postgres.dump.enc, or an unencrypted .dump)")
	flag.StringVar(&o.media, "media", "", "optional media backup to extract (fm-media-....tar.gz.enc)")
	flag.StringVar(&o.mediaDir, "media-dir", "media-restore", "folder the media backup is extracted into")
	flag.StringVar(&o.db, "db", "financial_manager", "name of the restored database (with -target, a database name in the URL wins)")
	flag.BoolVar(&o.replace, "replace", false, "discard an existing container (Docker) or database (-target) with the same name first")
	flag.StringVar(&o.name, "name", "fm-restore", "Docker: name of the PostgreSQL container")
	flag.IntVar(&o.port, "port", 15432, "Docker: host port (on 127.0.0.1) the database is published on")
	flag.StringVar(&o.password, "password", "restore", "Docker: password of the postgres user in the container")
	flag.StringVar(&o.target, "target", "", "restore into this PostgreSQL server instead of Docker, e.g. postgres://postgres@localhost:5432")
	flag.StringVar(&o.pgBin, "pg-bin", "", "-target: folder containing pg_restore and psql (default: PATH, then the usual install folders)")
	flag.Parse()
	if o.dump == "" && o.media == "" {
		flag.Usage()
		return errors.New("pass -dump and/or -media")
	}

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt)
	defer stop()

	var target pgTarget
	if o.dump != "" {
		var err error
		if target, err = newTarget(o); err != nil {
			return err
		}
	}

	key, err := encryptionKey()
	if err != nil {
		return err
	}

	if o.media != "" {
		if err := restoreMedia(o, key); err != nil {
			return err
		}
	}
	if target != nil {
		return restoreDatabase(ctx, target, o.dump, key, o.replace)
	}
	return nil
}

// dbNamePattern keeps database names to plain identifiers, so they can be
// interpolated into SQL and connection URLs without quoting concerns.
var dbNamePattern = regexp.MustCompile(`^[A-Za-z_][A-Za-z0-9_]{0,62}$`)

func newTarget(o options) (pgTarget, error) {
	if o.target != "" {
		return newLocalTarget(o.target, o.db, o.pgBin)
	}
	if !dbNamePattern.MatchString(o.db) {
		return nil, fmt.Errorf("invalid -db %q: use letters, digits and underscores", o.db)
	}
	return &dockerTarget{name: o.name, port: o.port, password: o.password, db: o.db}, nil
}

// encryptionKey reads BACKUP_ENCRYPTION_KEY, or prompts for it without
// echo so it never lands in the shell history or on screen.
func encryptionKey() (string, error) {
	if key := os.Getenv("BACKUP_ENCRYPTION_KEY"); key != "" {
		return key, nil
	}
	return promptSecret("BACKUP_ENCRYPTION_KEY: ", "BACKUP_ENCRYPTION_KEY is not set")
}

func promptSecret(prompt, missing string) (string, error) {
	fd := int(os.Stdin.Fd())
	if !term.IsTerminal(fd) {
		return "", errors.New(missing + " and stdin is not a terminal to prompt for it")
	}
	fmt.Fprint(os.Stderr, prompt)
	secret, err := term.ReadPassword(fd)
	fmt.Fprintln(os.Stderr)
	if err != nil {
		return "", fmt.Errorf("read input: %w", err)
	}
	if len(secret) == 0 {
		return "", errors.New("empty input")
	}
	return string(secret), nil
}

func restoreMedia(o options, key string) error {
	step("Decrypting media archive %s", filepath.Base(o.media))
	tmp, err := os.MkdirTemp("", "fm-restore-media-*")
	if err != nil {
		return err
	}
	defer os.RemoveAll(tmp)

	archive := filepath.Join(tmp, "media.tar.gz")
	if err := backup.DecryptFile(archive, o.media, key); err != nil {
		return err
	}
	step("Extracting into %s", o.mediaDir)
	stats, err := backup.ExtractMedia(archive, o.mediaDir)
	if err != nil {
		return err
	}
	abs, _ := filepath.Abs(o.mediaDir)
	fmt.Printf("    %d files, %.1f MB -> %s\n\n", stats.Objects, float64(stats.Bytes)/(1<<20), abs)
	return nil
}

func step(format string, args ...any) {
	fmt.Printf("==> "+format+"\n", args...)
}
