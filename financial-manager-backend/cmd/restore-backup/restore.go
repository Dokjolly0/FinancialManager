package main

import (
	"bufio"
	"context"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"

	"financial-manager-backend/internal/backup"
)

// pgTarget is a PostgreSQL server the dump can be restored into: a
// disposable Docker container, or a server installed on the machine.
type pgTarget interface {
	// check validates the target before anything is decrypted, so a
	// misconfiguration fails fast.
	check(ctx context.Context, replace bool) error
	// start brings the server up, if the target manages one.
	start(ctx context.Context, replace bool) error
	// stage makes a local dump file readable by the target's pg_restore,
	// returning the path to pass it and a cleanup function.
	stage(ctx context.Context, localPath string) (string, func(), error)
	// psql runs a SQL command against db (a database name) and returns
	// its unaligned, tab-separated output.
	psql(ctx context.Context, db, sql string) (string, error)
	// pgRestore restores dumpPath into the target database, streaming
	// pg_restore's output.
	pgRestore(ctx context.Context, dumpPath string) error
	// dbName is the database the dump is restored into.
	dbName() string
	// describe returns the connection details and cleanup instructions.
	describe() string
}

func restoreDatabase(ctx context.Context, t pgTarget, dumpFile, key string, replace bool) error {
	if err := t.check(ctx, replace); err != nil {
		return err
	}

	tmp, err := os.MkdirTemp("", "fm-restore-db-*")
	if err != nil {
		return err
	}
	// The decrypted dump is plaintext financial data: it only lives here,
	// until it has been restored.
	defer os.RemoveAll(tmp)

	dumpPath, err := plainDump(dumpFile, filepath.Join(tmp, "db.dump"), key)
	if err != nil {
		return err
	}

	if err := t.start(ctx, replace); err != nil {
		return err
	}
	staged, cleanup, err := t.stage(ctx, dumpPath)
	if err != nil {
		return err
	}
	defer cleanup()

	db := t.dbName()
	step("Restoring into database %q", db)
	if replace {
		if _, err := t.psql(ctx, "postgres", fmt.Sprintf(`DROP DATABASE IF EXISTS %q WITH (FORCE)`, db)); err != nil {
			return err
		}
	}
	if _, err := t.psql(ctx, "postgres", fmt.Sprintf(`CREATE DATABASE %q`, db)); err != nil {
		return err
	}
	// pg_restore exits non-zero even when it only skipped some objects, so
	// keep going and let the summary show what made it.
	if err := t.pgRestore(ctx, staged); err != nil {
		fmt.Fprintf(os.Stderr, "\nwarning: pg_restore reported errors (see above): %v\n", err)
	}

	printSummary(ctx, t)
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

func printSummary(ctx context.Context, t pgTarget) {
	fmt.Println()
	// Table statistics are refreshed lazily; ANALYZE makes the row counts
	// exact for a freshly restored database.
	_, _ = t.psql(ctx, t.dbName(), "ANALYZE")
	out, err := t.psql(ctx, t.dbName(), `SELECT relname, n_live_tup FROM pg_stat_user_tables ORDER BY relname`)
	if err == nil && strings.TrimSpace(out) != "" {
		fmt.Println("Restored tables (rows):")
		sc := bufio.NewScanner(strings.NewReader(out))
		for sc.Scan() {
			table, rows, _ := strings.Cut(sc.Text(), "\t")
			fmt.Printf("    %-32s %s\n", table, rows)
		}
		fmt.Println()
	}
	fmt.Print(t.describe())
}
