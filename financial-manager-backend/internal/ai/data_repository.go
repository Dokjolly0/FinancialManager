package ai

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
)

// Queries the reports module doesn't have, used only to build the AI data
// block. Like reports, they read soft-deleted rows out and take [from, to)
// with a nil from meaning the whole history.

// TransactionRow is one transaction as listed in the data block.
type TransactionRow struct {
	OccurredAt  time.Time
	WalletName  string
	Direction   string
	AmountMinor int64
	Title       string
	Category    *string
}

// ListTransactions returns the newest transactions of the given kinds,
// at most limit rows.
func (r *Repository) ListTransactions(ctx context.Context, walletIDs []uuid.UUID, kinds []string, from *time.Time, to time.Time, limit int) ([]TransactionRow, error) {
	rows, err := r.db.Query(ctx, `
		SELECT t.occurred_at, w.name, t.direction, t.amount_minor, t.title, c.name
		FROM transactions t
		JOIN wallets w ON w.id = t.wallet_id
		LEFT JOIN categories c ON c.id = t.category_id
		WHERE t.wallet_id = ANY($1::uuid[]) AND t.deleted_at IS NULL AND t.kind = ANY($2::text[])
			AND ($3::timestamptz IS NULL OR t.occurred_at >= $3)
			AND t.occurred_at < $4
		ORDER BY t.occurred_at DESC, t.id
		LIMIT $5
	`, walletIDs, kinds, from, to, limit)
	if err != nil {
		return nil, fmt.Errorf("list ai transactions: %w", err)
	}
	defer rows.Close()
	var out []TransactionRow
	for rows.Next() {
		var t TransactionRow
		if err := rows.Scan(&t.OccurredAt, &t.WalletName, &t.Direction, &t.AmountMinor, &t.Title, &t.Category); err != nil {
			return nil, fmt.Errorf("scan ai transaction: %w", err)
		}
		out = append(out, t)
	}
	return out, rows.Err()
}

// TransferFlowRow sums transfers from one wallet to another.
type TransferFlowRow struct {
	FromWallet  string
	ToWallet    string
	AmountMinor int64
	Count       int64
}

// TransferFlows sums the transfers whose source or destination is one of
// walletIDs, by (source, destination). A transfer is its DEBIT row on the
// source wallet, paired through transfer_pair_id with the CREDIT row on
// the destination (migration 0023).
func (r *Repository) TransferFlows(ctx context.Context, walletIDs []uuid.UUID, from *time.Time, to time.Time) ([]TransferFlowRow, error) {
	rows, err := r.db.Query(ctx, `
		SELECT ws.name, wd.name, SUM(d.amount_minor), COUNT(*)
		FROM transactions d
		JOIN transactions c ON c.id = d.transfer_pair_id
		JOIN wallets ws ON ws.id = d.wallet_id
		JOIN wallets wd ON wd.id = c.wallet_id
		WHERE d.kind = 'TRANSFER' AND d.direction = 'DEBIT' AND d.deleted_at IS NULL
			AND (d.wallet_id = ANY($1::uuid[]) OR c.wallet_id = ANY($1::uuid[]))
			AND ($2::timestamptz IS NULL OR d.occurred_at >= $2)
			AND d.occurred_at < $3
		GROUP BY ws.name, wd.name
		ORDER BY SUM(d.amount_minor) DESC
	`, walletIDs, from, to)
	if err != nil {
		return nil, fmt.Errorf("query transfer flows: %w", err)
	}
	defer rows.Close()
	var out []TransferFlowRow
	for rows.Next() {
		var f TransferFlowRow
		if err := rows.Scan(&f.FromWallet, &f.ToWallet, &f.AmountMinor, &f.Count); err != nil {
			return nil, fmt.Errorf("scan transfer flow: %w", err)
		}
		out = append(out, f)
	}
	return out, rows.Err()
}

// MonthlyTitleRow is one item's spending in one local month.
type MonthlyTitleRow struct {
	Key         string
	Label       string
	Month       string // YYYY-MM in tzName
	AmountMinor int64
	Count       int64
}

// MonthlyDebitsByTitle groups expenses by item (template, else normalized
// title, as reports.BreakdownByTitle does) and local month; the input of
// the recurring-payment detection.
func (r *Repository) MonthlyDebitsByTitle(ctx context.Context, walletIDs []uuid.UUID, kinds []string, from *time.Time, to time.Time, tzName string) ([]MonthlyTitleRow, error) {
	rows, err := r.db.Query(ctx, `
		SELECT
			COALESCE(t.template_id::text, 'title:' || t.title_normalized) AS group_key,
			COALESCE(MAX(tt.title), (ARRAY_AGG(t.title ORDER BY t.occurred_at DESC))[1]) AS label,
			to_char(t.occurred_at AT TIME ZONE $1, 'YYYY-MM') AS month,
			SUM(t.amount_minor),
			COUNT(*)
		FROM transactions t
		LEFT JOIN transaction_templates tt ON tt.id = t.template_id
		WHERE t.wallet_id = ANY($2::uuid[]) AND t.deleted_at IS NULL AND t.direction = 'DEBIT'
			AND t.kind = ANY($3::text[])
			AND ($4::timestamptz IS NULL OR t.occurred_at >= $4)
			AND t.occurred_at < $5
		GROUP BY group_key, month
		ORDER BY group_key, month
	`, tzName, walletIDs, kinds, from, to)
	if err != nil {
		return nil, fmt.Errorf("query monthly debits by title: %w", err)
	}
	defer rows.Close()
	var out []MonthlyTitleRow
	for rows.Next() {
		var m MonthlyTitleRow
		if err := rows.Scan(&m.Key, &m.Label, &m.Month, &m.AmountMinor, &m.Count); err != nil {
			return nil, fmt.Errorf("scan monthly debits: %w", err)
		}
		out = append(out, m)
	}
	return out, rows.Err()
}
