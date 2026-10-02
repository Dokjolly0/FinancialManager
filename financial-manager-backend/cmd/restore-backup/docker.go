package main

import (
	"bytes"
	"context"
	"fmt"
	"os"
	"os/exec"
	"strings"
	"time"
)

// postgresImage matches the server's major version (compose.yaml):
// pg_restore can't read a dump from a newer major version.
const postgresImage = "postgres:16-alpine"

// readyTimeout bounds the wait for the container's PostgreSQL to accept
// connections.
const readyTimeout = 60 * time.Second

// dockerTarget restores into a disposable postgres container published on
// 127.0.0.1. Needs only Docker on the machine, but the database is gone
// once the container is removed.
type dockerTarget struct {
	name     string
	port     int
	password string
	db       string
	exists   bool
}

func (d *dockerTarget) check(ctx context.Context, replace bool) error {
	if _, err := docker(ctx, "version", "--format", "{{.Server.Version}}"); err != nil {
		return fmt.Errorf("docker is not reachable — is Docker Desktop running? (%w)", err)
	}
	_, err := docker(ctx, "container", "inspect", d.name)
	d.exists = err == nil
	if d.exists && !replace {
		return fmt.Errorf("a container named %q already exists: rerun with -replace to discard it, or pick another -name", d.name)
	}
	return nil
}

func (d *dockerTarget) start(ctx context.Context, _ bool) error {
	if d.exists {
		step("Removing existing container %s", d.name)
		if _, err := docker(ctx, "rm", "-f", d.name); err != nil {
			return err
		}
	}
	step("Starting %s container %s on 127.0.0.1:%d", postgresImage, d.name, d.port)
	if _, err := docker(ctx, "run", "-d", "--name", d.name,
		"-e", "POSTGRES_PASSWORD="+d.password,
		"-p", fmt.Sprintf("127.0.0.1:%d:5432", d.port),
		postgresImage); err != nil {
		return err
	}
	step("Waiting for PostgreSQL to accept connections")
	return d.waitReady(ctx)
}

// waitReady polls over TCP rather than the Unix socket: the image's init
// phase runs a temporary server on the socket only, which would otherwise
// look ready and then restart under our feet.
func (d *dockerTarget) waitReady(ctx context.Context) error {
	deadline := time.Now().Add(readyTimeout)
	for {
		if _, err := docker(ctx, "exec", d.name, "pg_isready", "-h", "127.0.0.1", "-U", "postgres"); err == nil {
			return nil
		}
		if time.Now().After(deadline) {
			return fmt.Errorf("PostgreSQL in %s did not become ready within %s (docker logs %s)", d.name, readyTimeout, d.name)
		}
		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-time.After(time.Second):
		}
	}
}

func (d *dockerTarget) stage(ctx context.Context, localPath string) (string, func(), error) {
	const inContainer = "/tmp/db.dump"
	if _, err := docker(ctx, "cp", localPath, d.name+":"+inContainer); err != nil {
		return "", nil, err
	}
	cleanup := func() { _, _ = docker(context.Background(), "exec", d.name, "rm", "-f", inContainer) }
	return inContainer, cleanup, nil
}

func (d *dockerTarget) psql(ctx context.Context, db, sql string) (string, error) {
	return docker(ctx, "exec", d.name, "psql", "-U", "postgres", "-d", db,
		"-v", "ON_ERROR_STOP=1", "-At", "-F", "\t", "-c", sql)
}

// pgRestore uses --no-owner/--no-privileges because the dump's roles
// (financial_manager) don't exist in the container.
func (d *dockerTarget) pgRestore(ctx context.Context, dumpPath string) error {
	cmd := exec.CommandContext(ctx, "docker", "exec", d.name, "pg_restore", "-U", "postgres",
		"-d", d.db, "--no-owner", "--no-privileges", dumpPath)
	cmd.Stdout, cmd.Stderr = os.Stdout, os.Stderr
	return cmd.Run()
}

func (d *dockerTarget) dbName() string { return d.db }

func (d *dockerTarget) describe() string {
	return fmt.Sprintf(`Database ready. Connect with DataGrip (or any PostgreSQL client):
    Host      127.0.0.1
    Port      %d
    User      postgres
    Password  %s
    Database  %s
    URL       postgres://postgres:%s@127.0.0.1:%d/%s

When you're done, delete the container and the restored data with:
    docker rm -f %s
`, d.port, d.password, d.db, d.password, d.port, d.db, d.name)
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
