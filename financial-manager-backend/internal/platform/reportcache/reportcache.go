// Package reportcache caches report responses in Redis, keyed by a
// per-wallet version counter instead of individually-tracked keys (plan.md
// section 18.9: "La soluzione con versione evita scansioni di chiavi
// Redis"). Any transaction mutation bumps the wallet's version, which
// invalidates every cached report for that wallet in O(1) without a scan
// or an explicit key registry.
package reportcache

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/redis/go-redis/v9"

	"financial-manager-backend/internal/platform/metrics"
)

// ttl is a belt-and-suspenders expiry on top of version-based invalidation
// (plan.md section 18.9's third option), guarding against a missed Bump.
const ttl = 5 * time.Minute

type Store struct {
	redis *redis.Client
}

func New(r *redis.Client) *Store {
	return &Store{redis: r}
}

func versionKey(walletID uuid.UUID) string {
	return "reports:version:" + walletID.String()
}

// Bump advances a wallet's report version, invalidating every report cached
// under the previous version. Satisfies transactions.ReportVersionBumper.
func (s *Store) Bump(ctx context.Context, walletID uuid.UUID) error {
	if s == nil {
		return nil
	}
	return s.redis.Incr(ctx, versionKey(walletID)).Err()
}

func (s *Store) version(ctx context.Context, walletID uuid.UUID) (int64, error) {
	v, err := s.redis.Get(ctx, versionKey(walletID)).Int64()
	if errors.Is(err, redis.Nil) {
		return 0, nil
	}
	return v, err
}

// Cached returns the cached value for (walletIDs, endpoint, paramsKey) under
// the current report version of every wallet in walletIDs if present,
// otherwise it calls compute, caches the JSON-encoded result, and returns
// it. Reports scoped to "all wallets" (plan.md's wallet selector) pass every
// wallet the aggregate spans; a mutation on any one of them changes the key,
// so the cached aggregate is invalidated exactly like a single-wallet report
// would be. A nil Store (as left unset in tests that don't wire Redis) or
// any Redis error simply bypasses caching — correctness never depends on
// the cache being up.
func Cached[T any](ctx context.Context, s *Store, walletIDs []uuid.UUID, endpoint, paramsKey string, compute func() (T, error)) (T, error) {
	if s == nil {
		metrics.ReportCacheResult.WithLabelValues("bypass").Inc()
		return compute()
	}

	versions := make([]string, len(walletIDs))
	ids := make([]string, len(walletIDs))
	for i, id := range walletIDs {
		v, err := s.version(ctx, id)
		if err != nil {
			metrics.ReportCacheResult.WithLabelValues("bypass").Inc()
			return compute()
		}
		versions[i] = fmt.Sprintf("%d", v)
		ids[i] = id.String()
	}
	key := fmt.Sprintf("reports:%s:%s:%s:%s", strings.Join(versions, ","), strings.Join(ids, ","), endpoint, paramsKey)

	if raw, err := s.redis.Get(ctx, key).Bytes(); err == nil {
		var cached T
		if json.Unmarshal(raw, &cached) == nil {
			metrics.ReportCacheResult.WithLabelValues("hit").Inc()
			return cached, nil
		}
	}
	metrics.ReportCacheResult.WithLabelValues("miss").Inc()

	value, err := compute()
	if err != nil {
		var zero T
		return zero, err
	}
	if raw, err := json.Marshal(value); err == nil {
		_ = s.redis.Set(ctx, key, raw, ttl).Err()
	}
	return value, nil
}
