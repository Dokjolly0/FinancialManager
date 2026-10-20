package ai_test

import (
	"context"
	"net/http"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"

	"financial-manager-backend/internal/ai"
	"financial-manager-backend/internal/transactions"
	"financial-manager-backend/internal/wallets"
)

// seed adds a ledger row directly (balances are not needed by the AI data
// block, which reads totals from the ledger like the reports do).
func (h *harness) seed(walletID uuid.UUID, direction, kind string, amount int64, title string, at time.Time) uuid.UUID {
	h.t.Helper()
	tx, err := transactions.NewRepository(h.db).Create(context.Background(), transactions.CreateInput{
		WalletID: walletID, UserID: h.userID, Direction: direction, Kind: kind, AmountMinor: amount,
		Currency: "EUR", Title: title, OccurredAt: at,
	})
	if err != nil {
		h.t.Fatalf("seed transaction: %v", err)
	}
	return tx.ID
}

// seedTransfer adds a wallet-to-wallet transfer as the two paired rows.
func (h *harness) seedTransfer(from, to uuid.UUID, amount int64, at time.Time) {
	h.t.Helper()
	repo := transactions.NewRepository(h.db)
	debit, err := repo.Create(context.Background(), transactions.CreateInput{
		WalletID: from, UserID: h.userID, Direction: transactions.DirectionDebit, Kind: transactions.KindTransfer,
		AmountMinor: amount, Currency: "EUR", Title: "Trasferimento", OccurredAt: at,
	})
	if err != nil {
		h.t.Fatal(err)
	}
	credit, err := repo.Create(context.Background(), transactions.CreateInput{
		WalletID: to, UserID: h.userID, Direction: transactions.DirectionCredit, Kind: transactions.KindTransfer,
		AmountMinor: amount, Currency: "EUR", Title: "Trasferimento", OccurredAt: at, TransferPairID: &debit.ID,
	})
	if err != nil {
		h.t.Fatal(err)
	}
	if err := repo.SetTransferPairID(context.Background(), debit.ID, credit.ID); err != nil {
		h.t.Fatal(err)
	}
}

func (h *harness) secondWallet(name, purpose string) uuid.UUID {
	h.t.Helper()
	w, err := h.wallets.Create(context.Background(), wallets.CreateRowInput{
		UserID: h.userID, Name: name, Currency: "EUR", Type: wallets.TypeCash, Icon: "cash", Color: "#6750A4", Purpose: &purpose,
	})
	if err != nil {
		h.t.Fatal(err)
	}
	return w.ID
}

// seedLedger builds a small year of data: salary, rent, a monthly
// subscription, groceries, and a transfer to the cash wallet.
func (h *harness) seedLedger() uuid.UUID {
	cash := h.secondWallet("Contanti", "Piccole spese")
	for m := 0; m < 4; m++ {
		at := time.Date(2026, time.Month(6+m), 5, 9, 0, 0, 0, time.UTC)
		h.seed(h.walletID, transactions.DirectionCredit, transactions.KindStandard, 200000, "Stipendio", at)
		h.seed(h.walletID, transactions.DirectionDebit, transactions.KindStandard, 80000, "Affitto", at.Add(time.Hour))
		h.seed(h.walletID, transactions.DirectionDebit, transactions.KindStandard, 1299, "Netflix", at.Add(2*time.Hour))
	}
	h.seed(cash, transactions.DirectionDebit, transactions.KindStandard, 4550, "Spesa mercato", time.Date(2026, 9, 20, 9, 0, 0, 0, time.UTC))
	h.seedTransfer(h.walletID, cash, 10000, time.Date(2026, 9, 18, 9, 0, 0, 0, time.UTC))
	return cash
}

func previewBody(overrides map[string]any) map[string]any {
	body := map[string]any{
		"preset": "MONTHLY_CHECKUP",
		"period": map[string]any{"preset": "last_12_months"},
		"options": map[string]any{
			"sections": []string{"monthly", "categories", "titles", "transfers", "recurring", "personal_context"},
		},
	}
	for k, v := range overrides {
		body[k] = v
	}
	return body
}

func TestPreview_RequiresConsentAndProvider(t *testing.T) {
	h := newHarness(t)
	if r := h.do(http.MethodPost, "/v1/ai/analyses/preview", previewBody(nil)); r.status != http.StatusForbidden || r.errorCode() != "AI_CONSENT_REQUIRED" {
		t.Fatalf("without consent = %d %s", r.status, r.raw)
	}
	h.mustStatus(h.do(http.MethodPut, "/v1/ai/consent", map[string]any{"consent_version": ai.ConsentVersion}), http.StatusNoContent)
	if r := h.do(http.MethodPost, "/v1/ai/analyses/preview", previewBody(nil)); r.status != http.StatusConflict || r.errorCode() != "AI_NOT_CONFIGURED" {
		t.Fatalf("without provider = %d %s", r.status, r.raw)
	}
}

func TestPreview_DataBlock(t *testing.T) {
	h := newHarness(t)
	h.configure("sk-preview-0001")
	h.seedLedger()
	h.mustStatus(h.do(http.MethodPut, "/v1/ai/context", map[string]any{"goals": "Risparmiare per le vacanze", "version": 0}), http.StatusOK)

	r := h.do(http.MethodPost, "/v1/ai/analyses/preview", previewBody(nil))
	h.mustStatus(r, http.StatusOK)
	data := r.body["data_block"].(string)

	// Totals: 4 salaries in, rent + subscription + groceries out; the
	// 100.00 transfer is shown as a flow but not counted.
	for _, want := range []string{
		"8000.00 | 3297.46 | 4702.54 | 13 |",
		"Conto | Contanti | 100.00 | 1",
		"Contanti | contanti | Piccole spese |",
		"Netflix | 4 | 12.99 | 12.99 | 2026-09 | sì",
		"Affitto | 3200.00 |",
		"2026-06 | 2000.00 | 812.99 | 1187.01",
		"<user_context>\nObiettivi: Risparmiare per le vacanze",
	} {
		if !strings.Contains(data, want) {
			t.Errorf("data block lacks %q:\n%s", want, data)
		}
	}
	if strings.Contains(data, "## Movimenti") {
		t.Error("transactions must be opt-in")
	}
	if strings.Contains(data, "2026-05 |") || !strings.Contains(data, "2026-10 | 0.00 | 0.00 | 0.00") {
		t.Error("months before the first data must be trimmed, later empty months kept")
	}
	if r.body["provider"] != "openai" || r.body["model"] != "gpt-test" || r.body["max_output_tokens"] != float64(2048) {
		t.Fatalf("provider/model = %v %v %v", r.body["provider"], r.body["model"], r.body["max_output_tokens"])
	}
	if !strings.HasPrefix(r.body["instructions"].(string), "Fammi un check-up") {
		t.Fatalf("default Italian instructions expected: %v", r.body["instructions"])
	}
	if r.body["estimated_input_tokens"].(float64) <= 0 || len(r.body["data_fingerprint"].(string)) != 64 {
		t.Fatal("estimate/fingerprint missing")
	}
	disclosure := r.body["disclosure"].(map[string]any)
	if disclosure["wallet_count"] != float64(2) || disclosure["includes_personal_context"] != true || disclosure["transaction_count"] != float64(0) {
		t.Fatalf("disclosure = %v", disclosure)
	}
	if r.body["period_to"] != "2026-10-20" {
		t.Fatalf("period_to = %v", r.body["period_to"])
	}
}

func TestPreview_TransactionsAnonymizedAndCapped(t *testing.T) {
	h := newHarness(t)
	h.configure("sk-preview-0002")
	h.seedLedger()

	r := h.do(http.MethodPost, "/v1/ai/analyses/preview", previewBody(map[string]any{
		"options": map[string]any{
			"sections": []string{"titles", "recurring"}, "include_transactions": true,
			"max_transactions": 3, "anonymize_titles": true,
		},
	}))
	h.mustStatus(r, http.StatusOK)
	data := r.body["data_block"].(string)
	for _, secret := range []string{"Netflix", "Affitto", "Stipendio", "Spesa mercato"} {
		if strings.Contains(data, secret) {
			t.Errorf("anonymized block still contains %q", secret)
		}
	}
	if !strings.Contains(data, "Voce 1") || !strings.Contains(data, "Altri 10 movimenti meno recenti non sono inclusi.") {
		t.Fatalf("pseudonyms or omitted line missing:\n%s", data)
	}
	disclosure := r.body["disclosure"].(map[string]any)
	if disclosure["transaction_count"] != float64(3) || disclosure["transactions_omitted"] != float64(10) || disclosure["anonymized"] != true {
		t.Fatalf("disclosure = %v", disclosure)
	}
}

func TestPreview_WalletSelectionAndFingerprint(t *testing.T) {
	h := newHarness(t)
	h.configure("sk-preview-0003")
	cash := h.seedLedger()

	body := previewBody(map[string]any{"wallet_ids": []string{cash.String()}})
	first := h.do(http.MethodPost, "/v1/ai/analyses/preview", body)
	h.mustStatus(first, http.StatusOK)
	if data := first.body["data_block"].(string); strings.Contains(data, "Affitto") || !strings.Contains(data, "0.00 | 45.50 |") {
		t.Fatalf("only the cash wallet expected:\n%s", data)
	}

	again := h.do(http.MethodPost, "/v1/ai/analyses/preview", body)
	if again.body["data_fingerprint"] != first.body["data_fingerprint"] {
		t.Fatal("same data, different fingerprint")
	}
	h.seed(cash, transactions.DirectionDebit, transactions.KindStandard, 300, "Caffè", time.Date(2026, 10, 1, 8, 0, 0, 0, time.UTC))
	if changed := h.do(http.MethodPost, "/v1/ai/analyses/preview", body); changed.body["data_fingerprint"] == first.body["data_fingerprint"] {
		t.Fatal("fingerprint unchanged after a new transaction")
	}

	// Someone else's wallet is not found.
	other := newHarness(t)
	r := h.do(http.MethodPost, "/v1/ai/analyses/preview", previewBody(map[string]any{"wallet_ids": []string{other.walletID.String()}}))
	if r.fieldError("wallet_ids") != "WALLET_NOT_FOUND" {
		t.Fatalf("foreign wallet = %d %s", r.status, r.raw)
	}
}

func TestPreview_Validation(t *testing.T) {
	h := newHarness(t)
	h.configure("sk-preview-0004")
	cases := []struct {
		name  string
		body  map[string]any
		field string
	}{
		{"bad preset", previewBody(map[string]any{"preset": "NOPE"}), "preset"},
		{"bad section", previewBody(map[string]any{"options": map[string]any{"sections": []string{"secrets"}}}), "options.sections"},
		{"too many transactions", previewBody(map[string]any{"options": map[string]any{"include_transactions": true, "max_transactions": 501}}), "options.max_transactions"},
		{"custom without dates", previewBody(map[string]any{"period": map[string]any{"preset": "custom"}}), "period"},
		{"bad timezone", previewBody(map[string]any{"timezone": "Mars/Olympus"}), "timezone"},
		{"custom preset needs instructions", previewBody(map[string]any{"preset": "CUSTOM"}), "instructions"},
		{"instructions too long", previewBody(map[string]any{"instructions": strings.Repeat("a", ai.MaxInstructionsLength+1)}), "instructions"},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			r := h.do(http.MethodPost, "/v1/ai/analyses/preview", c.body)
			if r.status != http.StatusUnprocessableEntity || r.fieldError(c.field) == "" {
				t.Fatalf("= %d %s, want a %s field error", r.status, r.raw, c.field)
			}
		})
	}

	custom := h.do(http.MethodPost, "/v1/ai/analyses/preview", previewBody(map[string]any{
		"preset": "CUSTOM", "instructions": "  Quanto spendo per la casa?  ",
		"period": map[string]any{"preset": "custom", "from": "2026-06-01", "to": "2026-06-30"},
	}))
	h.mustStatus(custom, http.StatusOK)
	if custom.body["instructions"] != "Quanto spendo per la casa?" || custom.body["period_from"] != "2026-06-01" || custom.body["period_to"] != "2026-06-30" {
		t.Fatalf("custom = %s", custom.raw)
	}
}

func TestPreview_PromptTooLarge(t *testing.T) {
	h := newHarness(t, harnessOptions{maxPromptTokens: 1000})
	h.configure("sk-preview-0005")
	h.seedLedger()
	r := h.do(http.MethodPost, "/v1/ai/analyses/preview", previewBody(map[string]any{
		"options":      map[string]any{"include_transactions": true, "sections": []string{"monthly", "titles", "categories"}},
		"instructions": strings.Repeat("Analizza con attenzione. ", 150),
	}))
	if r.status != http.StatusUnprocessableEntity || r.errorCode() != "AI_PROMPT_TOO_LARGE" {
		t.Fatalf("= %d %s", r.status, r.raw)
	}
}

func TestPresets_Localized(t *testing.T) {
	h := newHarness(t)
	r := h.do(http.MethodGet, "/v1/ai/presets", nil)
	h.mustStatus(r, http.StatusOK)
	presets := r.body["presets"].([]any)
	first := presets[0].(map[string]any)
	if len(presets) != 6 || first["id"] != "MONTHLY_CHECKUP" || first["title"] != "Check-up del periodo" {
		t.Fatalf("presets = %v", presets)
	}
	if first["default_period_preset"] != "last_12_months" || len(first["default_sections"].([]any)) == 0 {
		t.Fatalf("defaults = %v", first)
	}
}
