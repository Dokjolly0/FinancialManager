package reports

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"

	"financial-manager-backend/internal/platform/database"
)

type Repository struct {
	db database.Querier
}

func NewRepository(db database.Querier) *Repository {
	return &Repository{db: db}
}

// SignedImpact sums each transaction's effect on the wallet balance
// (CREDIT positive, DEBIT negative) across every kind, within [from, to) —
// a nil bound is unbounded on that side. Used both for "opening balance"
// (from=nil, to=period.From) and "impact of the period" (from=period.From,
// to=period.To) — plan.md section 18.3.
func (r *Repository) SignedImpact(ctx context.Context, walletID uuid.UUID, from *time.Time, to *time.Time) (int64, error) {
	var sum int64
	err := r.db.QueryRow(ctx, `
		SELECT COALESCE(SUM(CASE WHEN direction = 'CREDIT' THEN amount_minor ELSE -amount_minor END), 0)
		FROM transactions
		WHERE wallet_id = $1 AND deleted_at IS NULL
			AND ($2::timestamptz IS NULL OR occurred_at >= $2)
			AND ($3::timestamptz IS NULL OR occurred_at < $3)
	`, walletID, from, to).Scan(&sum)
	if err != nil {
		return 0, fmt.Errorf("sum signed impact: %w", err)
	}
	return sum, nil
}

type Totals struct {
	CreditsMinor int64
	DebitsMinor  int64
	Count        int64
}

// Totals sums credits and debits separately (never netted) across the
// given kinds within [from, to) — plan.md section 18.3's
// total_credits/total_debits.
func (r *Repository) Totals(ctx context.Context, walletID uuid.UUID, kinds []string, from *time.Time, to time.Time) (Totals, error) {
	var t Totals
	err := r.db.QueryRow(ctx, `
		SELECT
			COALESCE(SUM(CASE WHEN direction = 'CREDIT' THEN amount_minor ELSE 0 END), 0),
			COALESCE(SUM(CASE WHEN direction = 'DEBIT' THEN amount_minor ELSE 0 END), 0),
			COUNT(*)
		FROM transactions
		WHERE wallet_id = $1 AND deleted_at IS NULL AND kind = ANY($2::text[])
			AND ($3::timestamptz IS NULL OR occurred_at >= $3)
			AND occurred_at < $4
	`, walletID, kinds, from, to).Scan(&t.CreditsMinor, &t.DebitsMinor, &t.Count)
	if err != nil {
		return Totals{}, fmt.Errorf("sum totals: %w", err)
	}
	return t, nil
}

type Bucket struct {
	PeriodStart  time.Time
	CreditsMinor int64
	DebitsMinor  int64
}

// Buckets groups transactions into daily or monthly buckets in the given
// IANA timezone (plan.md section 18.7, 7.12) — used for both the trend
// chart (granularity chosen by GranularityFor) and monthly comparison
// (always GranularityMonthly). Only buckets with at least one transaction
// are returned; callers fill the gaps (plan.md section 18.7: "Il backend
// deve riempire i mesi senza operazioni con zero").
func (r *Repository) Buckets(ctx context.Context, walletID uuid.UUID, kinds []string, from *time.Time, to time.Time, granularity string, tzName string) ([]Bucket, error) {
	trunc := "day"
	if granularity == GranularityMonthly {
		trunc = "month"
	}

	// date_trunc on a timestamptz shifted into tzName gives the local
	// bucket boundary as a naive timestamp; shifting it back through the
	// same timezone reinterprets that naive value as an instant, which is
	// the standard Postgres idiom for timezone-aware date_trunc.
	query := `
		SELECT
			(date_trunc('` + trunc + `', occurred_at AT TIME ZONE $1) AT TIME ZONE $1) AS bucket,
			COALESCE(SUM(CASE WHEN direction = 'CREDIT' THEN amount_minor ELSE 0 END), 0),
			COALESCE(SUM(CASE WHEN direction = 'DEBIT' THEN amount_minor ELSE 0 END), 0)
		FROM transactions
		WHERE wallet_id = $2 AND deleted_at IS NULL AND kind = ANY($3::text[])
			AND ($4::timestamptz IS NULL OR occurred_at >= $4)
			AND occurred_at < $5
		GROUP BY bucket
		ORDER BY bucket
	`
	rows, err := r.db.Query(ctx, query, tzName, walletID, kinds, from, to)
	if err != nil {
		return nil, fmt.Errorf("query buckets: %w", err)
	}
	defer rows.Close()

	var out []Bucket
	for rows.Next() {
		var b Bucket
		if err := rows.Scan(&b.PeriodStart, &b.CreditsMinor, &b.DebitsMinor); err != nil {
			return nil, fmt.Errorf("scan bucket: %w", err)
		}
		out = append(out, b)
	}
	return out, rows.Err()
}

type BreakdownGroup struct {
	Key              string
	Label            string
	AmountMinor      int64
	TransactionCount int64
}

// BreakdownByTitle implements plan.md section 18.4: coalesce by
// template_id when present (label = the template's canonical title),
// otherwise by title_normalized (label = the most recent raw title used).
func (r *Repository) BreakdownByTitle(ctx context.Context, walletID uuid.UUID, direction string, kinds []string, from *time.Time, to time.Time) ([]BreakdownGroup, error) {
	rows, err := r.db.Query(ctx, `
		SELECT
			COALESCE(t.template_id::text, 'title:' || t.title_normalized) AS group_key,
			COALESCE(MAX(tt.title), (ARRAY_AGG(t.title ORDER BY t.occurred_at DESC))[1]) AS label,
			SUM(t.amount_minor) AS amount_minor,
			COUNT(*) AS tx_count
		FROM transactions t
		LEFT JOIN transaction_templates tt ON tt.id = t.template_id
		WHERE t.wallet_id = $1 AND t.deleted_at IS NULL AND t.direction = $2 AND t.kind = ANY($3::text[])
			AND ($4::timestamptz IS NULL OR t.occurred_at >= $4)
			AND t.occurred_at < $5
		GROUP BY group_key
		ORDER BY amount_minor DESC
	`, walletID, direction, kinds, from, to)
	if err != nil {
		return nil, fmt.Errorf("query title breakdown: %w", err)
	}
	return scanBreakdownGroups(rows)
}

// BreakdownByCategory implements plan.md section 18.5: group by category,
// with uncategorized transactions bucketed under "Altro".
func (r *Repository) BreakdownByCategory(ctx context.Context, walletID uuid.UUID, direction string, kinds []string, from *time.Time, to time.Time) ([]BreakdownGroup, error) {
	rows, err := r.db.Query(ctx, `
		SELECT
			COALESCE(t.category_id::text, 'none') AS group_key,
			COALESCE(MAX(c.name), 'Altro') AS label,
			SUM(t.amount_minor) AS amount_minor,
			COUNT(*) AS tx_count
		FROM transactions t
		LEFT JOIN categories c ON c.id = t.category_id
		WHERE t.wallet_id = $1 AND t.deleted_at IS NULL AND t.direction = $2 AND t.kind = ANY($3::text[])
			AND ($4::timestamptz IS NULL OR t.occurred_at >= $4)
			AND t.occurred_at < $5
		GROUP BY group_key
		ORDER BY amount_minor DESC
	`, walletID, direction, kinds, from, to)
	if err != nil {
		return nil, fmt.Errorf("query category breakdown: %w", err)
	}
	return scanBreakdownGroups(rows)
}

func scanBreakdownGroups(rows interface {
	Next() bool
	Scan(...any) error
	Err() error
	Close()
}) ([]BreakdownGroup, error) {
	defer rows.Close()
	var out []BreakdownGroup
	for rows.Next() {
		var g BreakdownGroup
		if err := rows.Scan(&g.Key, &g.Label, &g.AmountMinor, &g.TransactionCount); err != nil {
			return nil, fmt.Errorf("scan breakdown group: %w", err)
		}
		out = append(out, g)
	}
	return out, rows.Err()
}
