// Command migrate applies or rolls back PostgreSQL schema migrations.
// It is meant to be run once per deploy (plan.md section 21.9), never
// concurrently from every API replica. It uses a PostgreSQL advisory lock
// (taken automatically by golang-migrate's postgres driver) as an
// additional safeguard against concurrent runs.
package main

import (
	"errors"
	"flag"
	"fmt"
	"os"

	"github.com/golang-migrate/migrate/v4"
	_ "github.com/golang-migrate/migrate/v4/database/postgres"
	_ "github.com/golang-migrate/migrate/v4/source/file"

	"financial-manager-backend/internal/platform/config"
)

func main() {
	direction := flag.String("direction", "up", "migration direction: up or down")
	steps := flag.Int("steps", 0, "number of steps to apply (0 = all)")
	migrationsPath := flag.String("path", "migrations", "path to migration files")
	flag.Parse()

	if err := run(*direction, *steps, *migrationsPath); err != nil {
		fmt.Fprintln(os.Stderr, "fatal:", err)
		os.Exit(1)
	}
}

func run(direction string, steps int, migrationsPath string) error {
	cfg, err := config.Load()
	if err != nil {
		return err
	}

	m, err := migrate.New("file://"+migrationsPath, cfg.DatabaseURL)
	if err != nil {
		return fmt.Errorf("init migrator: %w", err)
	}
	defer m.Close()

	var runErr error
	switch direction {
	case "up":
		if steps > 0 {
			runErr = m.Steps(steps)
		} else {
			runErr = m.Up()
		}
	case "down":
		if steps > 0 {
			runErr = m.Steps(-steps)
		} else {
			runErr = m.Down()
		}
	default:
		return fmt.Errorf("unknown direction %q, expected up or down", direction)
	}

	if runErr != nil && !errors.Is(runErr, migrate.ErrNoChange) {
		return fmt.Errorf("run migration: %w", runErr)
	}

	fmt.Println("migrations applied successfully")
	return nil
}
