// Command perftest measures API latency against plan.md section 23.9's
// targets (letture comuni p95 < 300ms, mutazioni p95 < 500ms escluso
// upload, report cached p95 < 250ms), against a dataset seeded by
// cmd/seedperf. It mints access tokens directly with the shared JWT
// signing key instead of logging in per user — access tokens are
// stateless (internal/auth/middleware.go never hits the database to
// validate one), so this measures the API's own request handling, not
// the login endpoint's bcrypt cost.
//
// Not part of the shipped API/worker images. Run locally against a
// disposable/dev database and a running API process:
//
//	go run ./cmd/perftest -base-url=http://localhost:10003 -users=1000 -requests=500
package main

import (
	"bytes"
	"context"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"log"
	"math/rand"
	"net/http"
	"os"
	"slices"
	"time"

	"github.com/google/uuid"

	"financial-manager-backend/internal/platform/config"
	"financial-manager-backend/internal/platform/database"
	"financial-manager-backend/internal/platform/security"
)

type scenario struct {
	name       string
	targetP95  time.Duration
	isMutation bool
	run        func(ctx context.Context, client *http.Client, baseURL, token string, rng *rand.Rand) error
}

func main() {
	baseURL := flag.String("base-url", "http://localhost:10003", "API base URL")
	userCount := flag.Int("users", 1000, "number of seeded perf users to draw tokens for")
	prefix := flag.String("prefix", "perfuser", "username prefix used by cmd/seedperf")
	requests := flag.Int("requests", 500, "requests to issue per scenario")
	concurrency := flag.Int("concurrency", 20, "concurrent workers per scenario")
	flag.Parse()

	if err := run(*baseURL, *userCount, *prefix, *requests, *concurrency); err != nil {
		fmt.Fprintln(os.Stderr, "fatal:", err)
		os.Exit(1)
	}
}

func run(baseURL string, userCount int, prefix string, requests, concurrency int) error {
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

	userIDs, err := loadSeededUserIDs(ctx, dbPool, prefix, userCount)
	if err != nil {
		return fmt.Errorf("load seeded users: %w", err)
	}
	if len(userIDs) == 0 {
		return fmt.Errorf("no users found matching prefix %q — run cmd/seedperf first", prefix)
	}
	log.Printf("found %d seeded users to draw tokens for", len(userIDs))

	// Mutation endpoints record created_by_session_id, a real FK into
	// sessions — a random session UUID in the token would make every
	// write 500. Give each user a throwaway session row so writes behave
	// exactly as they would for a real logged-in client.
	tokens := make([]string, len(userIDs))
	now := time.Now()
	for i, uid := range userIDs {
		sessionID := uuid.New()
		if _, err := dbPool.Exec(ctx, `
			INSERT INTO sessions (id, user_id, refresh_token_hash, expires_at)
			VALUES ($1, $2, $3, $4)
			ON CONFLICT (id) DO NOTHING
		`, sessionID, uid, []byte(uuid.New().String()), now.Add(24*time.Hour)); err != nil {
			return fmt.Errorf("create perftest session: %w", err)
		}

		token, err := security.IssueAccessToken(cfg.JWTSigningKey, uid, sessionID, time.Hour, now)
		if err != nil {
			return fmt.Errorf("issue token: %w", err)
		}
		tokens[i] = token
	}

	client := &http.Client{Timeout: 10 * time.Second}

	scenarios := []scenario{
		{
			name:      "GET /v1/transactions (lettura comune, filtrata)",
			targetP95: 300 * time.Millisecond,
			run:       listTransactions,
		},
		{
			name:      "GET /v1/reports/summary (all_time, non cached)",
			targetP95: 300 * time.Millisecond,
			run:       reportSummary,
		},
		{
			name:      "GET /v1/reports/summary (all_time, cached — ripetuta)",
			targetP95: 250 * time.Millisecond,
			run:       reportSummary,
		},
		{
			name:       "POST /v1/transactions (mutazione)",
			targetP95:  500 * time.Millisecond,
			isMutation: true,
			run:        createTransaction,
		},
	}

	fmt.Println()
	for _, sc := range scenarios {
		// Scenarios run in order and reuse the same tokens/users. The
		// "non cached" report scenario is each user's very first report
		// request (nothing to hit in Redis yet); the "cached" scenario
		// immediately after re-requests the identical report for the
		// same users with no mutation in between, so it's served from
		// Redis every time (plan.md 18.9's version-based invalidation
		// only bumps on a transaction write, and the mutation scenario
		// runs last, after both report scenarios).
		if err := runScenario(ctx, client, baseURL, tokens, sc, requests, concurrency); err != nil {
			return fmt.Errorf("scenario %q: %w", sc.name, err)
		}
	}
	return nil
}

func runScenario(ctx context.Context, client *http.Client, baseURL string, tokens []string, sc scenario, requests, concurrency int) error {
	durations := make(chan time.Duration, requests)
	errs := make(chan error, requests)
	jobs := make(chan int, requests)
	for i := range requests {
		jobs <- i
	}
	close(jobs)

	workerRNG := rand.New(rand.NewSource(time.Now().UnixNano()))
	done := make(chan struct{})
	for range concurrency {
		go func(seed int64) {
			rng := rand.New(rand.NewSource(seed))
			for i := range jobs {
				token := tokens[i%len(tokens)]
				start := time.Now()
				err := sc.run(ctx, client, baseURL, token, rng)
				durations <- time.Since(start)
				if err != nil {
					errs <- err
				}
			}
			done <- struct{}{}
		}(workerRNG.Int63())
	}
	for range concurrency {
		<-done
	}
	close(durations)
	close(errs)

	var samples []time.Duration
	for d := range durations {
		samples = append(samples, d)
	}
	errCount := len(errs)
	var firstErr error
	for e := range errs {
		if firstErr == nil {
			firstErr = e
		}
	}

	slices.Sort(samples)
	p50 := percentile(samples, 50)
	p95 := percentile(samples, 95)
	p99 := percentile(samples, 99)

	status := "OK"
	if p95 > sc.targetP95 {
		status = "SOPRA TARGET"
	}
	fmt.Printf("%-55s p50=%-8s p95=%-8s p99=%-8s target_p95=%-8s errori=%d/%d  [%s]\n",
		sc.name, p50.Round(time.Millisecond), p95.Round(time.Millisecond), p99.Round(time.Millisecond),
		sc.targetP95, errCount, requests, status)
	if firstErr != nil {
		fmt.Printf("  esempio errore: %v\n", firstErr)
	}
	return nil
}

func percentile(sorted []time.Duration, p int) time.Duration {
	if len(sorted) == 0 {
		return 0
	}
	idx := (p * len(sorted) / 100)
	if idx >= len(sorted) {
		idx = len(sorted) - 1
	}
	return sorted[idx]
}

func listTransactions(ctx context.Context, client *http.Client, baseURL, token string, rng *rand.Rand) error {
	req, _ := http.NewRequestWithContext(ctx, http.MethodGet, baseURL+"/v1/transactions?limit=20&direction=DEBIT", nil)
	req.Header.Set("Authorization", "Bearer "+token)
	return doAndCheck(client, req)
}

func reportSummary(ctx context.Context, client *http.Client, baseURL, token string, rng *rand.Rand) error {
	req, _ := http.NewRequestWithContext(ctx, http.MethodGet, baseURL+"/v1/reports/summary?preset=all_time&timezone=Europe/Rome", nil)
	req.Header.Set("Authorization", "Bearer "+token)
	return doAndCheck(client, req)
}

func createTransaction(ctx context.Context, client *http.Client, baseURL, token string, rng *rand.Rand) error {
	body, _ := json.Marshal(map[string]any{
		"direction":    "DEBIT",
		"amount_minor": rng.Intn(10000) + 100,
		"currency":     "EUR",
		"title":        "Operazione perftest",
		"occurred_at":  time.Now().Format(time.RFC3339),
	})
	req, _ := http.NewRequestWithContext(ctx, http.MethodPost, baseURL+"/v1/transactions", bytes.NewReader(body))
	req.Header.Set("Authorization", "Bearer "+token)
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Idempotency-Key", uuid.New().String())
	return doAndCheck(client, req)
}

func doAndCheck(client *http.Client, req *http.Request) error {
	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode >= 300 {
		body, _ := io.ReadAll(io.LimitReader(resp.Body, 1024))
		return fmt.Errorf("%s %s: unexpected status %d: %s", req.Method, req.URL.Path, resp.StatusCode, body)
	}
	return nil
}

func loadSeededUserIDs(ctx context.Context, dbPool *database.Pool, prefix string, limit int) ([]uuid.UUID, error) {
	rows, err := dbPool.Query(ctx,
		`SELECT id FROM users WHERE username_normalized LIKE $1 ORDER BY username_normalized LIMIT $2`,
		prefix+"%", limit,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var ids []uuid.UUID
	for rows.Next() {
		var id uuid.UUID
		if err := rows.Scan(&id); err != nil {
			return nil, err
		}
		ids = append(ids, id)
	}
	return ids, rows.Err()
}
