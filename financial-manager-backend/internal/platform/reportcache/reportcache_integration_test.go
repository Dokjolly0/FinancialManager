package reportcache_test

import (
	"context"
	"errors"
	"os"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/redis/go-redis/v9"

	"financial-manager-backend/internal/platform/reportcache"
)

// This test exercises reportcache against a real Redis — the same dev
// stack from `docker compose -f compose.yaml -f compose.dev.yaml up`.
// Skips automatically if the dev stack isn't reachable, so `go test ./...`
// stays green without Docker running.

func envOrDefault(key, def string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return def
}

func newTestStore(t *testing.T) *reportcache.Store {
	t.Helper()

	addr := envOrDefault("TEST_REDIS_ADDR", "localhost:10002")
	password := envOrDefault("TEST_REDIS_PASSWORD", "financial_manager")

	client := redis.NewClient(&redis.Options{Addr: addr, Password: password})

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := client.Ping(ctx).Err(); err != nil {
		t.Skipf("skipping: dev Redis not reachable at %s: %v", addr, err)
	}
	t.Cleanup(func() { _ = client.Close() })

	return reportcache.New(client)
}

type summaryLike struct {
	NetMinor int64 `json:"net_minor"`
}

func TestCached_HitsAfterFirstCompute(t *testing.T) {
	store := newTestStore(t)
	ctx := context.Background()
	walletID := uuid.New()

	calls := 0
	compute := func() (summaryLike, error) {
		calls++
		return summaryLike{NetMinor: 1234}, nil
	}

	first, err := reportcache.Cached(ctx, store, walletID, "summary", "key-a", compute)
	if err != nil {
		t.Fatalf("first Cached() error = %v", err)
	}
	second, err := reportcache.Cached(ctx, store, walletID, "summary", "key-a", compute)
	if err != nil {
		t.Fatalf("second Cached() error = %v", err)
	}

	if calls != 1 {
		t.Errorf("compute called %d times, want 1 (second call should hit cache)", calls)
	}
	if first != second || second.NetMinor != 1234 {
		t.Errorf("second = %+v, want %+v", second, first)
	}
}

func TestCached_BumpInvalidatesPreviousVersion(t *testing.T) {
	store := newTestStore(t)
	ctx := context.Background()
	walletID := uuid.New()

	calls := 0
	compute := func() (summaryLike, error) {
		calls++
		return summaryLike{NetMinor: int64(calls)}, nil
	}

	first, err := reportcache.Cached(ctx, store, walletID, "summary", "key-a", compute)
	if err != nil {
		t.Fatalf("first Cached() error = %v", err)
	}
	if err := store.Bump(ctx, walletID); err != nil {
		t.Fatalf("Bump() error = %v", err)
	}
	second, err := reportcache.Cached(ctx, store, walletID, "summary", "key-a", compute)
	if err != nil {
		t.Fatalf("second Cached() error = %v", err)
	}

	if calls != 2 {
		t.Errorf("compute called %d times, want 2 (bump must force a recompute)", calls)
	}
	if first.NetMinor == second.NetMinor {
		t.Errorf("first == second == %v, want the bump to have produced a fresh value", first.NetMinor)
	}
}

func TestCached_DifferentParamsKeysDoNotCollide(t *testing.T) {
	store := newTestStore(t)
	ctx := context.Background()
	walletID := uuid.New()

	a, err := reportcache.Cached(ctx, store, walletID, "summary", "key-a", func() (summaryLike, error) {
		return summaryLike{NetMinor: 1}, nil
	})
	if err != nil {
		t.Fatalf("Cached(key-a) error = %v", err)
	}
	b, err := reportcache.Cached(ctx, store, walletID, "summary", "key-b", func() (summaryLike, error) {
		return summaryLike{NetMinor: 2}, nil
	})
	if err != nil {
		t.Fatalf("Cached(key-b) error = %v", err)
	}

	if a.NetMinor == b.NetMinor {
		t.Errorf("distinct params keys collided: both resolved to %v", a.NetMinor)
	}
}

func TestCached_ComputeErrorIsNotCached(t *testing.T) {
	store := newTestStore(t)
	ctx := context.Background()
	walletID := uuid.New()
	wantErr := errors.New("boom")

	_, err := reportcache.Cached(ctx, store, walletID, "summary", "key-err", func() (summaryLike, error) {
		return summaryLike{}, wantErr
	})
	if !errors.Is(err, wantErr) {
		t.Fatalf("error = %v, want %v", err, wantErr)
	}

	calls := 0
	value, err := reportcache.Cached(ctx, store, walletID, "summary", "key-err", func() (summaryLike, error) {
		calls++
		return summaryLike{NetMinor: 99}, nil
	})
	if err != nil {
		t.Fatalf("retry Cached() error = %v", err)
	}
	if calls != 1 || value.NetMinor != 99 {
		t.Errorf("retry after a failed compute must not be served a cached error; calls=%d value=%+v", calls, value)
	}
}

func TestNilStore_BypassesCaching(t *testing.T) {
	ctx := context.Background()
	walletID := uuid.New()

	var store *reportcache.Store // left unset, as in tests that don't wire Redis

	calls := 0
	compute := func() (summaryLike, error) {
		calls++
		return summaryLike{NetMinor: int64(calls)}, nil
	}

	first, err := reportcache.Cached(ctx, store, walletID, "summary", "key-a", compute)
	if err != nil {
		t.Fatalf("first Cached() error = %v", err)
	}
	second, err := reportcache.Cached(ctx, store, walletID, "summary", "key-a", compute)
	if err != nil {
		t.Fatalf("second Cached() error = %v", err)
	}

	if calls != 2 {
		t.Errorf("compute called %d times, want 2 (nil store must never cache)", calls)
	}
	if first.NetMinor == second.NetMinor {
		t.Errorf("first == second with a nil store, want no caching to have occurred")
	}

	if err := store.Bump(ctx, walletID); err != nil {
		t.Errorf("Bump() on nil store must be a no-op, got error = %v", err)
	}
}
