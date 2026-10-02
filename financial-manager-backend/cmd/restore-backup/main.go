// Command restore-backup turns an encrypted backup (as uploaded to Google
// Drive by the worker, or written by scripts/backup.sh) back into a running
// PostgreSQL database on your own machine, ready to browse with DataGrip,
// psql or any other client:
//
//	go run ./cmd/restore-backup -dump fm-20261001T154350Z-postgres.dump.enc
//
// It decrypts the dump (no openssl needed), starts a disposable
// postgres:16-alpine container bound to 127.0.0.1, restores the dump into
// it and prints the connection details. With -media it also decrypts and
// extracts the media archive into a folder.
//
// The passphrase is read from BACKUP_ENCRYPTION_KEY or, if unset, prompted
// for without echo. Requires Docker (Docker Desktop on Windows/macOS).
//
// This is for inspecting and verifying backups locally. To restore onto the
// server's own stack, use scripts/restore.sh.
package main

import (
	"bufio"
	"bytes"
	"context"
	"errors"
	"flag"
	"fmt"
	"io"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"strings"
	"time"

	"golang.org/x/term"

	"financial-manager-backend/internal/backup"
)

// postgresImage matches the server's major version (compose.yaml):
// pg_restore can't read a dump from a newer major version.
const postgresImage = "postgres:16-alpine"

// readyTimeout bounds the wait for the container's PostgreSQL to accept
// connections.
const readyTimeout = 60 * time.Second

type options struct {
	dump     string
	media    string
	mediaDir string
	name     string
	port     int
	db       string
	password string
	replace  bool
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
	flag.StringVar(&o.name, "name", "fm-restore", "name of the PostgreSQL container")
	flag.IntVar(&o.port, "port", 15432, "host port (on 127.0.0.1) the database is published on")
	flag.StringVar(&o.db, "db", "financial_manager", "name of the restored database")
	flag.StringVar(&o.password, "password", "restore", "password of the postgres user in the container")
	flag.BoolVar(&o.replace, "replace", false, "remove an existing container with the same name first")
	flag.Parse()
	if o.dump == "" && o.media == "" {
		flag.Usage()
		return errors.New("pass -dump and/or -media")
	}

	ctx, stop := signal.NotifyContext(context.Background(), os.Interrupt)
	defer stop()

	key, err := encryptionKey()
	if err != nil {
		return err
	}

	if o.media != "" {
		if err := restoreMedia(o, key); err != nil {
			return err
		}
	}
	if o.dump != "" {
		if err := restoreDatabase(ctx, o, key); err != nil {
			return err
		}
	}
	return nil
}

// encryptionKey reads BACKUP_ENCRYPTION_KEY, or prompts for it without
// echo so it never lands in the shell history or on screen.
func encryptionKey() (string, error) {
	if key := os.Getenv("BACKUP_ENCRYPTION_KEY"); key != "" {
		return key, nil
	}
	fd := int(os.Stdin.Fd())
	if !term.IsTerminal(fd) {
		return "", errors.New("BACKUP_ENCRYPTION_KEY is not set and stdin is not a terminal to prompt for it")
	}
	fmt.Fprint(os.Stderr, "BACKUP_ENCRYPTION_KEY: ")
	key, err := term.ReadPassword(fd)
	fmt.Fprintln(os.Stderr)
	if err != nil {
		return "", fmt.Errorf("read key: %w", err)
	}
	if len(key) == 0 {
		return "", errors.New("empty key")
	}
	return string(key), nil
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

func restoreDatabase(ctx context.Context, o options, key string) error {
	if _, err := docker(ctx, "version", "--format", "{{.Server.Version}}"); err != nil {
		return fmt.Errorf("docker is not reachable — is Docker Desktop running? (%w)", err)
	}
	exists := containerExists(ctx, o.name)
	if exists && !o.replace {
		return fmt.Errorf("a container named %q already exists: rerun with -replace to discard it, or pick another -name", o.name)
	}

	tmp, err := os.MkdirTemp("", "fm-restore-db-*")
	if err != nil {
		return err
	}
	// The decrypted dump is plaintext financial data: it only lives here,
	// until it has been copied into the container.
	defer os.RemoveAll(tmp)

	dumpPath, err := plainDump(o.dump, filepath.Join(tmp, "db.dump"), key)
	if err != nil {
		return err
	}

	if err := startContainer(ctx, o, exists); err != nil {
		return err
	}
	step("Waiting for PostgreSQL to accept connections")
	if err := waitReady(ctx, o.name); err != nil {
		return err
	}

	step("Restoring into database %q", o.db)
	if _, err := docker(ctx, "cp", dumpPath, o.name+":/tmp/db.dump"); err != nil {
		return err
	}
	if _, err := docker(ctx, "exec", o.name, "createdb", "-U", "postgres", o.db); err != nil {
		return err
	}
	// --no-owner/--no-privileges: the dump's roles (financial_manager)
	// don't exist in this container; everything is owned by postgres.
	restoreErr := dockerStream(ctx, "exec", o.name, "pg_restore", "-U", "postgres", "-d", o.db,
		"--no-owner", "--no-privileges", "/tmp/db.dump")
	_, _ = docker(ctx, "exec", o.name, "rm", "-f", "/tmp/db.dump")
	if restoreErr != nil {
		// pg_restore exits non-zero even when it only skipped some objects,
		// so keep going and let the summary show what made it.
		fmt.Fprintf(os.Stderr, "\nwarning: pg_restore reported errors (see above): %v\n", restoreErr)
	}

	printSummary(ctx, o)
	return nil
}

// plainDump returns the path of an unencrypted pg_dump archive: src itself
// if it already is one, otherwise src decrypted into dst.
func plainDump(src, dst, key string) (string, error) {
	err := backup.DecryptFile(dst, src, key)
	if errors.Is(err, backup.ErrNotEncrypted) && isPgDump(src) {
		step("%s is not encrypted, using it as is", filepath.Base(src))
		return src, nil
	}
	if err != nil {
		return "", err
	}
	step("Decrypted %s", filepath.Base(src))
	if !isPgDump(dst) {
		return "", errors.New("decrypted file is not a pg_dump archive — wrong BACKUP_ENCRYPTION_KEY?")
	}
	return dst, nil
}

// isPgDump checks for the custom-format pg_dump signature.
func isPgDump(path string) bool {
	f, err := os.Open(path)
	if err != nil {
		return false
	}
	defer f.Close()
	magic := make([]byte, 5)
	_, err = io.ReadFull(f, magic)
	return err == nil && string(magic) == "PGDMP"
}

func containerExists(ctx context.Context, name string) bool {
	_, err := docker(ctx, "container", "inspect", name)
	return err == nil
}

// startContainer starts the disposable PostgreSQL container, first
// removing the existing one when replace was requested.
func startContainer(ctx context.Context, o options, exists bool) error {
	if exists {
		step("Removing existing container %s", o.name)
		if _, err := docker(ctx, "rm", "-f", o.name); err != nil {
			return err
		}
	}
	step("Starting %s container %s on 127.0.0.1:%d", postgresImage, o.name, o.port)
	_, err := docker(ctx, "run", "-d", "--name", o.name,
		"-e", "POSTGRES_PASSWORD="+o.password,
		"-p", fmt.Sprintf("127.0.0.1:%d:5432", o.port),
		postgresImage)
	return err
}

// waitReady polls over TCP rather than the Unix socket: the image's init
// phase runs a temporary server on the socket only, which would otherwise
// look ready and then restart under our feet.
func waitReady(ctx context.Context, name string) error {
	deadline := time.Now().Add(readyTimeout)
	for {
		if _, err := docker(ctx, "exec", name, "pg_isready", "-h", "127.0.0.1", "-U", "postgres"); err == nil {
			return nil
		}
		if time.Now().After(deadline) {
			return fmt.Errorf("PostgreSQL in %s did not become ready within %s (docker logs %s)", name, readyTimeout, name)
		}
		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-time.After(time.Second):
		}
	}
}

func printSummary(ctx context.Context, o options) {
	fmt.Println()
	// Table statistics are refreshed lazily; ANALYZE makes the row counts
	// exact for a freshly restored database.
	_, _ = docker(ctx, "exec", o.name, "psql", "-U", "postgres", "-d", o.db, "-c", "ANALYZE")
	out, err := docker(ctx, "exec", o.name, "psql", "-U", "postgres", "-d", o.db, "-At", "-F", "\t", "-c",
		`SELECT relname, n_live_tup FROM pg_stat_user_tables ORDER BY relname`)
	if err == nil && strings.TrimSpace(out) != "" {
		fmt.Println("Restored tables (rows):")
		sc := bufio.NewScanner(strings.NewReader(out))
		for sc.Scan() {
			table, rows, _ := strings.Cut(sc.Text(), "\t")
			fmt.Printf("    %-32s %s\n", table, rows)
		}
		fmt.Println()
	}

	fmt.Printf(`Database ready. Connect with DataGrip (or any PostgreSQL client):
    Host      127.0.0.1
    Port      %d
    User      postgres
    Password  %s
    Database  %s
    URL       postgres://postgres:%s@127.0.0.1:%d/%s

When you're done, delete the container and the restored data with:
    docker rm -f %s
`, o.port, o.password, o.db, o.password, o.port, o.db, o.name)
}

func step(format string, args ...any) {
	fmt.Printf("==> "+format+"\n", args...)
}

// docker runs a docker CLI command and returns its stdout; on failure the
// error carries stderr.
func docker(ctx context.Context, args ...string) (string, error) {
	var stdout, stderr bytes.Buffer
	cmd := exec.CommandContext(ctx, "docker", args...)
	cmd.Stdout, cmd.Stderr = &stdout, &stderr
	if err := cmd.Run(); err != nil {
		return "", fmt.Errorf("docker %s: %w: %s", args[0], err, strings.TrimSpace(stderr.String()))
	}
	return stdout.String(), nil
}

// dockerStream runs a docker CLI command with its output shown live.
func dockerStream(ctx context.Context, args ...string) error {
	cmd := exec.CommandContext(ctx, "docker", args...)
	cmd.Stdout, cmd.Stderr = os.Stdout, os.Stderr
	return cmd.Run()
}
