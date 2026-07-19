// Command seedperf seeds a synthetic dataset for performance testing
// (plan.md section 23.9: "10.000 transazioni per utente, 1.000 utenti
// attivi di test"). It writes directly to PostgreSQL via bulk COPY,
// bypassing the API — issuing 10M individual HTTP requests to build the
// dataset would dwarf the load test itself.
//
// Not part of the shipped API/worker images. Run locally against a
// disposable/dev database only:
//
//	go run ./cmd/seedperf -users=1000 -transactions-per-user=10000
//
// Seeded rows are identifiable by the -prefix flag (default "perfuser"),
// so they can be found and removed later:
//
//	DELETE FROM users WHERE username_normalized LIKE 'perfuser%';
package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"math/rand"
	"os"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"

	"financial-manager-backend/internal/platform/config"
	"financial-manager-backend/internal/platform/database"
	"financial-manager-backend/internal/transactions"
)

func main() {
	userCount := flag.Int("users", 1000, "number of synthetic users to create")
	txPerUser := flag.Int("transactions-per-user", 10000, "transactions per user")
	prefix := flag.String("prefix", "perfuser", "username/email prefix for seeded rows, so they stay identifiable and cleanable")
	seed := flag.Int64("seed", 42, "PRNG seed, for reproducible datasets across runs")
	flag.Parse()

	if err := run(*userCount, *txPerUser, *prefix, *seed); err != nil {
		fmt.Fprintln(os.Stderr, "fatal:", err)
		os.Exit(1)
	}
}

func run(userCount, txPerUser int, prefix string, seed int64) error {
	cfg, err := config.Load()
	if err != nil {
		return err
	}

	ctx := context.Background()
	dbPool, err := database.Connect(ctx, cfg.DatabaseURL)
	if err != nil {
		return fmt.Errorf("connect database: %w", err)
	}
	defer dbPool.Close()

	debitCategories, creditCategories, err := loadSystemCategories(ctx, dbPool)
	if err != nil {
		return fmt.Errorf("load system categories: %w", err)
	}
	if len(debitCategories) == 0 || len(creditCategories) == 0 {
		return fmt.Errorf("expected seeded system categories (migration 0012) to already be applied")
	}

	rng := rand.New(rand.NewSource(seed))
	startedAt := time.Now()

	for u := range userCount {
		if err := seedOneUser(ctx, dbPool, rng, u, txPerUser, prefix, debitCategories, creditCategories); err != nil {
			return fmt.Errorf("seed user %d: %w", u, err)
		}

		if (u+1)%50 == 0 || u == userCount-1 {
			log.Printf("seeded %d/%d users (%s elapsed)", u+1, userCount, time.Since(startedAt).Round(time.Second))
		}
	}

	log.Printf("done: %d users x %d transactions in %s", userCount, txPerUser, time.Since(startedAt).Round(time.Second))
	return nil
}

func seedOneUser(ctx context.Context, dbPool *database.Pool, rng *rand.Rand, index, txPerUser int, prefix string, debitCategories, creditCategories []uuid.UUID) error {
	userID := uuid.New()
	walletID := uuid.New()
	username := fmt.Sprintf("%s%06d", prefix, index)
	email := fmt.Sprintf("%s@perf.test", username)

	if _, err := dbPool.Exec(ctx, `
		INSERT INTO users (
			id, first_name, last_name, username, username_normalized,
			email, email_normalized, email_verified_at,
			avatar_background_color, avatar_text_color, status
		) VALUES ($1, 'Perf', 'Test', $2, $2, $3, $3, now(), '#176B5B', '#FFFFFF', 'active')
	`, userID, username, email); err != nil {
		return fmt.Errorf("insert user: %w", err)
	}

	if _, err := dbPool.Exec(ctx, `
		INSERT INTO wallets (id, user_id, current_balance_minor) VALUES ($1, $2, 0)
	`, walletID, userID); err != nil {
		return fmt.Errorf("insert wallet: %w", err)
	}

	now := time.Now()
	rows := make([][]any, 0, txPerUser)
	var balance int64
	for t := range txPerUser {
		direction := transactions.DirectionDebit
		categoryID := debitCategories[rng.Intn(len(debitCategories))]
		if rng.Intn(3) == 0 {
			direction = transactions.DirectionCredit
			categoryID = creditCategories[rng.Intn(len(creditCategories))]
		}
		amountMinor := int64(rng.Intn(50000) + 100) // 1.00 - 500.00 EUR
		title := fmt.Sprintf("Operazione sintetica %d", t)
		occurredAt := now.AddDate(0, 0, -rng.Intn(3*365))
		balance += transactions.SignedDelta(direction, amountMinor)

		rows = append(rows, []any{
			uuid.New(), walletID, userID, direction, transactions.KindStandard,
			amountMinor, "EUR", title, transactions.NormalizeTitle(title), categoryID, occurredAt,
		})
	}

	if _, err := dbPool.CopyFrom(ctx,
		pgx.Identifier{"transactions"},
		[]string{
			"id", "wallet_id", "user_id", "direction", "kind",
			"amount_minor", "currency", "title", "title_normalized", "category_id", "occurred_at",
		},
		pgx.CopyFromRows(rows),
	); err != nil {
		return fmt.Errorf("copy transactions: %w", err)
	}

	if _, err := dbPool.Exec(ctx, `UPDATE wallets SET current_balance_minor = $1 WHERE id = $2`, balance, walletID); err != nil {
		return fmt.Errorf("update wallet balance: %w", err)
	}
	return nil
}

func loadSystemCategories(ctx context.Context, dbPool *database.Pool) (debit, credit []uuid.UUID, err error) {
	rows, err := dbPool.Query(ctx, `SELECT id, direction_scope FROM categories WHERE owner_user_id IS NULL AND archived_at IS NULL`)
	if err != nil {
		return nil, nil, err
	}
	defer rows.Close()

	for rows.Next() {
		var id uuid.UUID
		var scope string
		if err := rows.Scan(&id, &scope); err != nil {
			return nil, nil, err
		}
		switch scope {
		case "DEBIT":
			debit = append(debit, id)
		case "CREDIT":
			credit = append(credit, id)
		}
	}
	return debit, credit, rows.Err()
}
