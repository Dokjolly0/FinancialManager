// Package ratelimit implements fixed-window rate limiting on top of Redis
// (plan.md section 12.1/19.5), used for login, password reset, and other
// sensitive endpoints. Redis is an accelerator here, not a source of
// truth: worst case of a Redis outage is temporarily permissive or
// unavailable rate limiting, never data loss (plan.md section 12).
package ratelimit

import (
	"context"
	"fmt"
	"time"

	"github.com/redis/go-redis/v9"
)

// Limiter checks fixed-window request limits per key.
type Limiter struct {
	client *redis.Client
}

func New(client *redis.Client) *Limiter {
	return &Limiter{client: client}
}

// Result of an Allow check.
type Result struct {
	Allowed    bool
	RetryAfter time.Duration
}

// Allow increments the counter for key within the current window and
// reports whether the caller is still under limit. The first increment in
// a window sets the window's expiry.
func (l *Limiter) Allow(ctx context.Context, key string, limit int, window time.Duration) (Result, error) {
	count, err := l.client.Incr(ctx, key).Result()
	if err != nil {
		return Result{}, fmt.Errorf("incr rate limit key: %w", err)
	}

	if count == 1 {
		if err := l.client.Expire(ctx, key, window).Err(); err != nil {
			return Result{}, fmt.Errorf("set rate limit expiry: %w", err)
		}
	}

	if count <= int64(limit) {
		return Result{Allowed: true}, nil
	}

	ttl, err := l.client.TTL(ctx, key).Result()
	if err != nil || ttl < 0 {
		ttl = window
	}
	return Result{Allowed: false, RetryAfter: ttl}, nil
}
