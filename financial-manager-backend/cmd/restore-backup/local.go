package main

import (
	"bytes"
	"context"
	"errors"
	"fmt"
	"net/url"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"runtime"
	"sort"
	"strconv"
	"strings"
)

// minPGRestoreMajor is the oldest pg_restore that can read the server's
// dumps: pg_dump 16 writes them, and pg_restore only reads its own or
// older major versions.
const minPGRestoreMajor = 16

// localTarget restores into a PostgreSQL server installed on the machine
// (e.g. the Windows installer's service), using that installation's
// pg_restore and psql. The database outlives the command — no Docker
// needed to browse it later.
type localTarget struct {
	binDir string
	server *url.URL // without password and database
	db     string
	env    []string // os.Environ plus PGPASSWORD
	exists bool
}

func newLocalTarget(rawURL, defaultDB, pgBin string) (*localTarget, error) {
	u, err := url.Parse(rawURL)
	if err != nil || (u.Scheme != "postgres" && u.Scheme != "postgresql") || u.Host == "" {
		return nil, fmt.Errorf("invalid -target %q: expected postgres://user@host:port[/database]", rawURL)
	}
	db := strings.TrimPrefix(u.Path, "/")
	if db == "" {
		db = defaultDB
	}
	if !dbNamePattern.MatchString(db) {
		return nil, fmt.Errorf("invalid database name %q: use letters, digits and underscores", db)
	}
	if db == "postgres" || strings.HasPrefix(db, "template") {
		return nil, fmt.Errorf("refusing to restore into the system database %q: pick another name", db)
	}

	binDir, err := findPGBin(pgBin)
	if err != nil {
		return nil, err
	}

	user := "postgres"
	password, hasPassword := "", false
	if u.User != nil {
		if name := u.User.Username(); name != "" {
			user = name
		}
		password, hasPassword = u.User.Password()
	}
	if !hasPassword {
		password = os.Getenv("PGPASSWORD")
	}
	if password == "" {
		password, err = promptSecret(fmt.Sprintf("Password for %s@%s: ", user, u.Host), "no password in -target or PGPASSWORD")
		if err != nil {
			return nil, err
		}
	}

	// The password reaches the tools through PGPASSWORD, never on their
	// command line where other processes could read it.
	server := &url.URL{Scheme: "postgres", User: url.User(user), Host: u.Host, RawQuery: u.RawQuery}
	return &localTarget{
		binDir: binDir,
		server: server,
		db:     db,
		env:    append(os.Environ(), "PGPASSWORD="+password),
	}, nil
}

func (l *localTarget) urlFor(db string) string {
	u := *l.server
	u.Path = "/" + db
	return u.String()
}

func (l *localTarget) check(ctx context.Context, replace bool) error {
	out, err := l.psql(ctx, "postgres", fmt.Sprintf(`SELECT 1 FROM pg_database WHERE datname = '%s'`, l.db))
	if err != nil {
		return fmt.Errorf("can't connect to %s — is the PostgreSQL service running and the password right? (%w)", l.server.Host, err)
	}
	l.exists = strings.TrimSpace(out) == "1"
	if l.exists && !replace {
		return fmt.Errorf("database %q already exists on %s: rerun with -replace to drop and recreate it, or pick another -db", l.db, l.server.Host)
	}
	return nil
}

func (l *localTarget) start(context.Context, bool) error {
	if l.exists {
		step("Dropping existing database %q on %s", l.db, l.server.Host)
	}
	return nil
}

func (l *localTarget) stage(_ context.Context, localPath string) (string, func(), error) {
	return localPath, func() {}, nil
}

func (l *localTarget) psql(ctx context.Context, db, sql string) (string, error) {
	var stdout, stderr bytes.Buffer
	cmd := exec.CommandContext(ctx, l.tool("psql"), "-d", l.urlFor(db),
		"-v", "ON_ERROR_STOP=1", "-At", "-F", "\t", "-c", sql)
	cmd.Env = l.env
	cmd.Stdout, cmd.Stderr = &stdout, &stderr
	if err := cmd.Run(); err != nil {
		return "", fmt.Errorf("psql: %w: %s", err, strings.TrimSpace(stderr.String()))
	}
	return stdout.String(), nil
}

// pgRestore uses --no-owner/--no-privileges because the dump's roles
// (financial_manager) don't exist on this server: everything ends up owned
// by the connecting user.
func (l *localTarget) pgRestore(ctx context.Context, dumpPath string) error {
	cmd := exec.CommandContext(ctx, l.tool("pg_restore"), "-d", l.urlFor(l.db),
		"--no-owner", "--no-privileges", dumpPath)
	cmd.Env = l.env
	cmd.Stdout, cmd.Stderr = os.Stdout, os.Stderr
	return cmd.Run()
}

func (l *localTarget) dbName() string { return l.db }

func (l *localTarget) describe() string {
	host, port := l.server.Hostname(), l.server.Port()
	if port == "" {
		port = "5432"
	}
	return fmt.Sprintf(`Database ready. It lives on your PostgreSQL server, so it stays available
without Docker. Connect with DataGrip (or any PostgreSQL client):
    Host      %s
    Port      %s
    User      %s
    Password  (the one of your PostgreSQL installation)
    Database  %s

To delete it when you no longer need it (from DataGrip, or):
    "%s" -d "%s" -c "DROP DATABASE %s WITH (FORCE)"
`, host, port, l.server.User.Username(), l.db, l.tool("psql"), l.urlFor("postgres"), l.db)
}

func (l *localTarget) tool(name string) string {
	if runtime.GOOS == "windows" {
		name += ".exe"
	}
	return filepath.Join(l.binDir, name)
}

// findPGBin locates a folder with pg_restore and psql: -pg-bin if given,
// then PATH, then the folders the Windows installers use (the newest
// PostgreSQL version first, then pgAdmin's bundled tools). The installer
// doesn't add its bin folder to PATH, hence the search.
func findPGBin(explicit string) (string, error) {
	var candidates []string
	if explicit != "" {
		candidates = []string{explicit}
	} else {
		if p, err := exec.LookPath("pg_restore"); err == nil {
			candidates = append(candidates, filepath.Dir(p))
		}
		if runtime.GOOS == "windows" {
			candidates = append(candidates, windowsPGBinDirs()...)
		}
	}

	var tooOld []string
	for _, dir := range candidates {
		restore, err := exec.LookPath(filepath.Join(dir, "pg_restore"))
		if err != nil {
			continue
		}
		if _, err := exec.LookPath(filepath.Join(dir, "psql")); err != nil {
			continue
		}
		major, version, err := pgRestoreVersion(restore)
		if err != nil {
			continue
		}
		if major < minPGRestoreMajor {
			tooOld = append(tooOld, fmt.Sprintf("%s (%s)", dir, version))
			continue
		}
		step("Using pg_restore %s from %s", version, dir)
		return dir, nil
	}

	if explicit != "" {
		return "", fmt.Errorf("no usable pg_restore %d+ and psql in -pg-bin %q", minPGRestoreMajor, explicit)
	}
	msg := fmt.Sprintf("pg_restore %d+ and psql not found: install PostgreSQL %d or newer, or pass -pg-bin", minPGRestoreMajor, minPGRestoreMajor)
	if len(tooOld) > 0 {
		msg += "; too old: " + strings.Join(tooOld, ", ")
	}
	return "", errors.New(msg)
}

func windowsPGBinDirs() []string {
	var dirs []string
	for _, root := range []string{os.Getenv("ProgramFiles"), os.Getenv("ProgramW6432")} {
		if root == "" {
			continue
		}
		matches, _ := filepath.Glob(filepath.Join(root, "PostgreSQL", "*", "bin"))
		dirs = append(dirs, matches...)
	}
	// Newest major version first: "18" before "16".
	sort.SliceStable(dirs, func(i, j int) bool {
		return installVersion(dirs[i]) > installVersion(dirs[j])
	})
	if local := os.Getenv("LOCALAPPDATA"); local != "" {
		dirs = append(dirs, filepath.Join(local, "Programs", "pgAdmin 4", "runtime"))
	}
	if pf := os.Getenv("ProgramFiles"); pf != "" {
		dirs = append(dirs, filepath.Join(pf, "pgAdmin 4", "runtime"))
	}
	return dirs
}

// installVersion parses the version folder of ...\PostgreSQL\<version>\bin.
func installVersion(binDir string) float64 {
	v, _ := strconv.ParseFloat(filepath.Base(filepath.Dir(binDir)), 64)
	return v
}

var pgVersionPattern = regexp.MustCompile(`(\d+)(\.\d+)?`)

func pgRestoreVersion(path string) (int, string, error) {
	out, err := exec.Command(path, "--version").Output()
	if err != nil {
		return 0, "", err
	}
	m := pgVersionPattern.FindStringSubmatch(string(out))
	if m == nil {
		return 0, "", fmt.Errorf("unrecognized version output %q", out)
	}
	major, _ := strconv.Atoi(m[1])
	return major, m[0], nil
}
