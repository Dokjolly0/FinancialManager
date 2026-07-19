// Package metrics exposes Prometheus metrics for the backend (plan.md
// section 22.1). It complements, rather than replaces, the structured
// per-request access log already emitted by httpserver.RequestLogger:
// logs answer "what happened on this one request", these answer "what's
// the aggregate p95/error-rate/etc. right now."
package metrics

import (
	"net/http"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

var (
	// HTTPRequestsTotal / HTTPRequestDuration cover plan.md 22.1's
	// "richieste per endpoint/status" and "latenza p50/p95/p99" (a
	// histogram lets Prometheus compute any percentile at query time).
	HTTPRequestsTotal = promauto.NewCounterVec(prometheus.CounterOpts{
		Name: "financialmanager_http_requests_total",
		Help: "Total HTTP requests, by method, route pattern, and status code.",
	}, []string{"method", "route", "status"})

	HTTPRequestDuration = promauto.NewHistogramVec(prometheus.HistogramOpts{
		Name:    "financialmanager_http_request_duration_seconds",
		Help:    "HTTP request latency in seconds, by method and route pattern.",
		Buckets: prometheus.DefBuckets,
	}, []string{"method", "route"})

	// RateLimitTriggered covers "rate limit attivati", labeled by the
	// caller-supplied scope (e.g. "login", "password-reauth", not the
	// full per-user Redis key, which would be unbounded cardinality).
	RateLimitTriggered = promauto.NewCounterVec(prometheus.CounterOpts{
		Name: "financialmanager_rate_limit_triggered_total",
		Help: "Requests rejected by rate limiting, by scope.",
	}, []string{"scope"})

	// ReportCacheResult covers "hit/miss cache Redis" for reports —
	// the one Redis-cached read path in the backend (internal/platform/reportcache).
	ReportCacheResult = promauto.NewCounterVec(prometheus.CounterOpts{
		Name: "financialmanager_report_cache_result_total",
		Help: "Report cache lookups, by result (hit/miss/bypass).",
	}, []string{"result"})

	// UploadsRejected covers "upload rifiutati", labeled by the reason
	// (format, size, pixels, rate-limit).
	UploadsRejected = promauto.NewCounterVec(prometheus.CounterOpts{
		Name: "financialmanager_uploads_rejected_total",
		Help: "Media uploads rejected before storage, by reason.",
	}, []string{"reason"})

	// ImageProcessingDuration covers "tempo processamento immagini" —
	// decode/crop/resize/re-encode, not the network fetch/upload time.
	ImageProcessingDuration = promauto.NewHistogram(prometheus.HistogramOpts{
		Name:    "financialmanager_image_processing_duration_seconds",
		Help:    "Time spent decoding, cropping, resizing, and re-encoding an uploaded image.",
		Buckets: prometheus.DefBuckets,
	})

	// JobRunsTotal covers "job falliti" for the worker's periodic jobs
	// (reconciliation, media cleanup, account purge), labeled by job name
	// and outcome so both rates and failures are visible.
	JobRunsTotal = promauto.NewCounterVec(prometheus.CounterOpts{
		Name: "financialmanager_job_runs_total",
		Help: "Worker job runs, by job name and outcome (ok/failed).",
	}, []string{"job", "outcome"})

	// ReconciliationMismatches covers "differenze rilevate dalla
	// riconciliazione saldo" directly, beyond just pass/fail.
	ReconciliationMismatches = promauto.NewCounter(prometheus.CounterOpts{
		Name: "financialmanager_reconciliation_mismatches_total",
		Help: "Wallets found with a stored balance disagreeing with their ledger, across all reconciliation runs.",
	})
)

// dbPoolCollector reports pgxpool's live stats on every scrape (plan.md
// 22.1 "connessioni pool PostgreSQL") rather than on a timer, so the
// numbers are never stale between scrapes.
type dbPoolCollector struct {
	pool *pgxpool.Pool

	acquired *prometheus.Desc
	idle     *prometheus.Desc
	total    *prometheus.Desc
	max      *prometheus.Desc
}

// RegisterDBPool wires a pgxpool.Pool's live stats into the default
// registry. Call once per pool at startup.
func RegisterDBPool(pool *pgxpool.Pool) {
	prometheus.MustRegister(&dbPoolCollector{
		pool:     pool,
		acquired: prometheus.NewDesc("financialmanager_db_pool_acquired_conns", "Connections currently acquired from the pool.", nil, nil),
		idle:     prometheus.NewDesc("financialmanager_db_pool_idle_conns", "Idle connections in the pool.", nil, nil),
		total:    prometheus.NewDesc("financialmanager_db_pool_total_conns", "Total connections currently open in the pool.", nil, nil),
		max:      prometheus.NewDesc("financialmanager_db_pool_max_conns", "Configured maximum pool size.", nil, nil),
	})
}

func (c *dbPoolCollector) Describe(ch chan<- *prometheus.Desc) {
	ch <- c.acquired
	ch <- c.idle
	ch <- c.total
	ch <- c.max
}

func (c *dbPoolCollector) Collect(ch chan<- prometheus.Metric) {
	stat := c.pool.Stat()
	ch <- prometheus.MustNewConstMetric(c.acquired, prometheus.GaugeValue, float64(stat.AcquiredConns()))
	ch <- prometheus.MustNewConstMetric(c.idle, prometheus.GaugeValue, float64(stat.IdleConns()))
	ch <- prometheus.MustNewConstMetric(c.total, prometheus.GaugeValue, float64(stat.TotalConns()))
	ch <- prometheus.MustNewConstMetric(c.max, prometheus.GaugeValue, float64(stat.MaxConns()))
}

// Handler serves the Prometheus exposition format for scraping.
func Handler() http.Handler {
	return promhttp.Handler()
}

// ObserveImageProcessingSince lets a call site wrap a pipeline with
// `defer metrics.ObserveImageProcessingSince(time.Now())` — time.Since is
// evaluated when the deferred call actually runs, at the end of the
// pipeline, not when defer is registered.
func ObserveImageProcessingSince(start time.Time) {
	ImageProcessingDuration.Observe(time.Since(start).Seconds())
}
