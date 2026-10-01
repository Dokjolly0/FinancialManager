package backup

import (
	"bytes"
	"context"
	"fmt"
	"os/exec"
	"strings"
)

// pgDumpBinary is the pg_dump executable; the worker image installs the
// client matching the server's major version (postgresql16-client), since
// pg_dump refuses to dump a newer server.
const pgDumpBinary = "pg_dump"

// DumpDatabase writes a custom-format (pg_restore-able, compressed) dump of
// databaseURL to path — the same format scripts/backup.sh produces, so
// scripts/restore.sh handles both.
func DumpDatabase(ctx context.Context, databaseURL, path string) error {
	var stderr bytes.Buffer
	cmd := exec.CommandContext(ctx, pgDumpBinary,
		"--format=custom",
		"--no-password", // fail fast instead of prompting if the URL lacks one
		"--file", path,
		"--dbname", databaseURL,
	)
	cmd.Stderr = &stderr
	if err := cmd.Run(); err != nil {
		// Only stderr is surfaced: the command line carries the database
		// URL, password included, and must never reach the logs.
		return fmt.Errorf("pg_dump: %w: %s", err, strings.TrimSpace(stderr.String()))
	}
	return nil
}
