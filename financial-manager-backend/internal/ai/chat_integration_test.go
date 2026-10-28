package ai_test

import (
	"context"
	"fmt"
	"net/http"
	"strings"
	"testing"
	"time"

	"financial-manager-backend/internal/ai"
	"financial-manager-backend/internal/ai/prompt"
	"financial-manager-backend/internal/transactions"
)

func chatBody(question string, options map[string]any) map[string]any {
	body := map[string]any{"preset": "CHAT", "instructions": question}
	if options != nil {
		body["options"] = options
	}
	return body
}

func TestChat_PreviewRunAndFollowUp(t *testing.T) {
	h := newHarness(t)
	h.configure("sk-chat-0001")
	h.seedLedger()
	const question = "  Quando ho pagato\nl'affitto?  "

	p := h.do(http.MethodPost, "/v1/ai/analyses/preview", chatBody(question, nil))
	h.mustStatus(p, http.StatusOK)
	system := p.body["system_prompt"].(string)
	if !strings.Contains(system, "<question>") || strings.Contains(system, "##") {
		t.Fatalf("chat system prompt:\n%s", system)
	}
	data := p.body["data_block"].(string)
	// Whole history, every movement listed, but no transfers section.
	if !strings.Contains(data, "Tutta la cronologia") || !strings.Contains(data, "## Movimenti (dal più recente)") ||
		!strings.Contains(data, "| Affitto |") || strings.Contains(data, "## Trasferimenti") {
		t.Fatalf("chat data block:\n%s", data)
	}
	disclosure := p.body["disclosure"].(map[string]any)
	if disclosure["transaction_count"] != float64(13) || disclosure["transactions_omitted"] != float64(0) {
		t.Fatalf("disclosure = %v", disclosure)
	}

	h.fake.Deltas = []string{"Il 5 di ogni mese."}
	res := h.stream("/v1/ai/analyses", h.runBody(chatBody(question, nil)), nil)
	if res.status != http.StatusOK || res.text() != "Il 5 di ogni mese." {
		t.Fatalf("chat run = %d %v %q", res.status, res.names(), res.text())
	}
	analysisID := res.events[0].data["analysis_id"].(string)
	first := h.fake.LastRequest()
	// The data, the totals of the question's word, then the question.
	if first.System != system || len(first.Messages) != 1 ||
		!strings.HasPrefix(first.Messages[0].Content, data+"\n\n<financial_data>\n## Totali calcolati per la domanda\n") ||
		!strings.Contains(first.Messages[0].Content, "### Parola \"affit\"\nmese | uscite | entrate | movimenti\n2026-06 | 800.00 | 0.00 | 1\n") ||
		!strings.Contains(first.Messages[0].Content, "Totale: uscite 3200.00, entrate 0.00, 4 movimenti.\nMedia mensile delle uscite: 640.00 su 5 mesi") ||
		!strings.HasSuffix(first.Messages[0].Content, "</financial_data>\n\n"+prompt.FollowUpQuestion(question, prompt.LangIT, prompt.PresetChat)) {
		t.Fatalf("first chat request = %+v", first)
	}

	detail := h.do(http.MethodGet, "/v1/ai/analyses/"+analysisID, nil)
	if detail.body["preset"] != "CHAT" || detail.body["title"] != "Quando ho pagato l'affitto?" ||
		detail.body["question"] != "Quando ho pagato\nl'affitto?" {
		t.Fatalf("chat detail = %s", detail.raw)
	}

	// Follow-ups keep the chat prompt and tag questions the same way.
	h.fake.Deltas = []string{"800.00 al mese."}
	h.stream("/v1/ai/analyses/"+analysisID+"/messages", map[string]any{"content": "Quanto?"}, nil)
	sent := h.fake.LastRequest()
	if sent.System != system || len(sent.Messages) != 3 || sent.Messages[1].Content != "Il 5 di ogni mese." ||
		sent.Messages[2].Content != prompt.FollowUpQuestion("Quanto?", prompt.LangIT, prompt.PresetChat) {
		t.Fatalf("chat follow-up = %+v", sent)
	}

	// The report setup doesn't offer chats.
	presets := h.do(http.MethodGet, "/v1/ai/presets", nil).body["presets"].([]any)
	for _, p := range presets {
		if p.(map[string]any)["id"] == "CHAT" {
			t.Fatal("CHAT listed among the report presets")
		}
	}
}

func TestChat_Validation(t *testing.T) {
	h := newHarness(t)
	h.configure("sk-chat-0002")
	h.seedLedger()
	for _, c := range []struct {
		name, field, code string
		body              map[string]any
	}{
		{"no question", "instructions", "REQUIRED_FIELD", map[string]any{"preset": "CHAT"}},
		{"blank question", "instructions", "REQUIRED_FIELD", chatBody("   ", nil)},
		{"question too long", "instructions", ai.FieldTextTooLong, chatBody(strings.Repeat("a", ai.MaxQuestionLength+1), nil)},
		{"anonymized titles", "options.anonymize_titles", ai.FieldInvalidValue, chatBody("Quando?", map[string]any{"anonymize_titles": true})},
		{"ledger too long", "options.max_transactions", ai.FieldOutOfRange, chatBody("Quando?", map[string]any{"max_transactions": ai.ChatMaxTransactions + 1})},
	} {
		t.Run(c.name, func(t *testing.T) {
			r := h.do(http.MethodPost, "/v1/ai/analyses/preview", c.body)
			if r.fieldError(c.field) != c.code {
				t.Fatalf("%s = %d %s", c.field, r.status, r.raw)
			}
		})
	}
	// A report keeps its own transaction cap.
	if r := h.do(http.MethodPost, "/v1/ai/analyses/preview", previewBody(map[string]any{
		"options": map[string]any{"include_transactions": true, "max_transactions": ai.MaxMaxTransactions + 1},
	})); r.fieldError("options.max_transactions") != ai.FieldOutOfRange {
		t.Fatalf("report cap = %s", r.raw)
	}
}

// A ledger over the budget is cut to its most recent transactions before
// any other detail is given up.
func TestChat_LedgerFitsTheBudget(t *testing.T) {
	h := newHarness(t)
	h.configure("sk-chat-0003")
	start := time.Date(2025, 1, 1, 9, 0, 0, 0, time.UTC)
	for i := 0; i < 300; i++ {
		h.seed(h.walletID, transactions.DirectionDebit, transactions.KindStandard, int64(500+i),
			fmt.Sprintf("Spesa numero %d al supermercato", i), start.Add(time.Duration(i)*24*time.Hour))
	}
	r := h.do(http.MethodPost, "/v1/ai/analyses/preview", chatBody("Quando ho fatto la spesa?", map[string]any{"budget_tokens": 3000}))
	h.mustStatus(r, http.StatusOK)
	d := r.body["disclosure"].(map[string]any)
	steps := d["compaction_steps"].([]any)
	kept := int(d["transaction_count"].(float64))
	if kept == 0 || kept >= 300 || d["transactions_omitted"] != float64(300-kept) ||
		len(steps) == 0 || steps[0] != fmt.Sprintf("transactions_%d", kept) {
		t.Fatalf("disclosure = %v", d)
	}
	if est := r.body["estimated_input_tokens"].(float64); est > 3000 {
		t.Fatalf("estimate %v over budget", est)
	}
	// The newest are kept.
	if data := r.body["data_block"].(string); !strings.Contains(data, "Spesa numero 299 al supermercato") ||
		strings.Contains(data, "| Spesa numero 0 al supermercato |") {
		t.Fatalf("wrong transactions kept:\n%s", data)
	}
	// Same request, same fingerprint: a run rebuilds its preview.
	again := h.do(http.MethodPost, "/v1/ai/analyses/preview", chatBody("Quando ho fatto la spesa?", map[string]any{"budget_tokens": 3000}))
	if again.body["data_fingerprint"] != r.body["data_fingerprint"] {
		t.Fatal("fitting the ledger is not deterministic")
	}
}

func TestChat_OnDevice(t *testing.T) {
	h := newHarness(t, harnessOptions{onDevice: true})
	h.seedLedger()
	h.acceptLocalConsent()
	body := chatBody("Quanto pago di Netflix?", map[string]any{"profile": "compact", "budget_tokens": 9000})
	body["target"] = "on_device"
	body["device"] = map[string]any{"context_tokens": 16384, "max_output_tokens": 1024}
	p := h.do(http.MethodPost, "/v1/ai/analyses/preview", body)
	h.mustStatus(p, http.StatusOK)
	if !strings.Contains(p.body["system_prompt"].(string), "Al massimo circa 200 parole") {
		t.Fatalf("compact chat prompt:\n%s", p.body["system_prompt"])
	}
	body["data_fingerprint"] = p.body["data_fingerprint"]
	body["client_request_id"] = "8f0e4a52-6a43-4d3e-9a4b-2f3a9d6c1e01"
	body["runtime"] = testRuntime
	prep := h.do(http.MethodPost, "/v1/ai/local/analyses", body)
	h.mustStatus(prep, http.StatusCreated)
	id := prep.body["analysis_id"].(string)
	h.mustStatus(h.do(http.MethodPut, resultPath(id, prep.body["message_id"].(string)),
		map[string]any{"content": "12.99 al mese.", "status": "COMPLETED"}), http.StatusOK)

	q := h.do(http.MethodPost, "/v1/ai/local/analyses/"+id+"/messages", map[string]any{"content": "E in un anno?"})
	h.mustStatus(q, http.StatusCreated)
	msgs := q.body["messages"].([]any)
	// The first answer is labelled as an answer, not a report.
	for i, kind := range []string{"CONTEXT", "ANSWER", "QUESTION"} {
		if got := msgs[i].(map[string]any)["kind"]; got != kind {
			t.Fatalf("message %d kind = %v, want %s", i, got, kind)
		}
	}
	if q.body["system_prompt"] != p.body["system_prompt"] ||
		msgs[2].(map[string]any)["content"] != prompt.FollowUpQuestion("E in un anno?", prompt.LangIT, prompt.PresetChat) {
		t.Fatalf("local chat follow-up = %s", q.raw)
	}
}

func TestHistory_TypeFilter(t *testing.T) {
	h := newHarness(t)
	h.configure("sk-chat-0004")
	h.seedLedger()
	h.fake.Deltas = []string{"Report."}
	h.stream("/v1/ai/analyses", h.runBody(previewBody(nil)), nil)
	h.fake.Deltas = []string{"Risposta."}
	h.stream("/v1/ai/analyses", h.runBody(chatBody("Quanto spendo?", nil)), nil)

	presetsOf := func(query string) []string {
		r := h.do(http.MethodGet, "/v1/ai/analyses"+query, nil)
		h.mustStatus(r, http.StatusOK)
		var out []string
		for _, it := range r.body["items"].([]any) {
			out = append(out, it.(map[string]any)["preset"].(string))
		}
		return out
	}
	if got := presetsOf(""); len(got) != 2 {
		t.Fatalf("all = %v", got)
	}
	if got := presetsOf("?type=chat"); len(got) != 1 || got[0] != "CHAT" {
		t.Fatalf("chats = %v", got)
	}
	if got := presetsOf("?type=report"); len(got) != 1 || got[0] != "MONTHLY_CHECKUP" {
		t.Fatalf("reports = %v", got)
	}
	if r := h.do(http.MethodGet, "/v1/ai/analyses?type=other", nil); r.fieldError("type") != ai.FieldInvalidValue {
		t.Fatalf("bad type = %s", r.raw)
	}
}

// A chat whose ledger was cut attaches the older transactions matching
// each question, stores them with it and replays them as sent.
func TestChat_SearchesOlderTransactions(t *testing.T) {
	h := newHarness(t)
	h.configure("sk-chat-0005")
	old := time.Date(2024, 6, 1, 9, 0, 0, 0, time.UTC)
	h.seed(h.walletID, transactions.DirectionDebit, transactions.KindStandard, 48000, "Assicurazione macchina", old)
	h.seed(h.walletID, transactions.DirectionDebit, transactions.KindStandard, 21000, "Bollo auto", old.AddDate(0, 1, 0))
	h.seed(h.walletID, transactions.DirectionDebit, transactions.KindStandard, 150, "Caffè al bar", old.AddDate(0, 2, 0))
	// Not in the chat: another wallet, another user.
	other := h.secondWallet("Carta", "Spese online")
	h.seed(other, transactions.DirectionDebit, transactions.KindStandard, 99900, "Assicurazione casa", old)
	stranger := newHarness(t)
	stranger.seed(stranger.walletID, transactions.DirectionDebit, transactions.KindStandard, 77700, "Assicurazione moto", old)
	start := time.Date(2025, 1, 1, 9, 0, 0, 0, time.UTC)
	for i := 0; i < 300; i++ {
		h.seed(h.walletID, transactions.DirectionDebit, transactions.KindStandard, int64(500+i),
			fmt.Sprintf("Spesa numero %d al supermercato", i), start.Add(time.Duration(i)*24*time.Hour))
	}

	body := chatBody("Quando ho pagato l'assicurazione della macchina?", map[string]any{"budget_tokens": 3000})
	body["wallet_ids"] = []string{h.walletID.String()}
	p := h.do(http.MethodPost, "/v1/ai/analyses/preview", body)
	h.mustStatus(p, http.StatusOK)
	if est := p.body["estimated_input_tokens"].(float64); est > 3000 {
		t.Fatalf("estimate %v over budget", est)
	}
	h.fake.Deltas = []string{"Il 1 giugno 2024."}
	res := h.stream("/v1/ai/analyses", h.runBody(body), nil)
	id := res.events[0].data["analysis_id"].(string)
	first := h.fake.LastRequest().Messages[0].Content
	if !strings.Contains(first, "## Movimenti meno recenti che corrispondono alla domanda") ||
		!strings.Contains(first, "| Assicurazione macchina |") || strings.Contains(first, "Assicurazione casa") ||
		strings.Contains(first, "Assicurazione moto") ||
		!strings.HasSuffix(first, prompt.FollowUpQuestion("Quando ho pagato l'assicurazione della macchina?", prompt.LangIT, prompt.PresetChat)) {
		t.Fatalf("first message:\n%s", first)
	}
	detail := h.do(http.MethodGet, "/v1/ai/analyses/"+id, nil)
	if detail.body["options"].(map[string]any)["ledger_cutoff"] == nil {
		t.Fatalf("no ledger cutoff stored: %s", detail.raw)
	}

	// A later question gets its own matches, accents folded ("caffe").
	h.fake.Deltas = []string{"Il 1 agosto 2024."}
	h.stream("/v1/ai/analyses/"+id+"/messages", map[string]any{"content": "E il caffe?"}, nil)
	asked := h.fake.LastRequest().Messages[2].Content
	if !strings.Contains(asked, "| Caffè al bar |") || strings.Contains(asked, "Assicurazione macchina") ||
		!strings.HasSuffix(asked, prompt.FollowUpQuestion("E il caffe?", prompt.LangIT, prompt.PresetChat)) {
		t.Fatalf("follow-up with attachment:\n%s", asked)
	}
	detail = h.do(http.MethodGet, "/v1/ai/analyses/"+id, nil)
	q := detail.body["messages"].([]any)[2].(map[string]any)
	if q["content"] != "E il caffe?" || q["attachment"] == nil || !strings.Contains(q["attachment"].(string), "Caffè al bar") {
		t.Fatalf("stored question = %v", q)
	}

	// Replayed exactly; a question with nothing to search carries nothing.
	h.fake.Deltas = []string{"Ok."}
	h.stream("/v1/ai/analyses/"+id+"/messages", map[string]any{"content": "Quanto?"}, nil)
	sent := h.fake.LastRequest()
	if sent.Messages[2].Content != asked || sent.Messages[4].Content != prompt.FollowUpQuestion("Quanto?", prompt.LangIT, prompt.PresetChat) {
		t.Fatalf("replay = %q / %q", sent.Messages[2].Content, sent.Messages[4].Content)
	}

	// The export keeps the attachment.
	exported, err := h.repo.ListAnalysesForExport(context.Background(), h.userID)
	if err != nil {
		t.Fatal(err)
	}
	if msgs := exported[0].Messages; msgs[2].Attachment == nil || *msgs[2].Attachment != q["attachment"] {
		t.Fatalf("exported attachment = %v", msgs[2].Attachment)
	}
}

// When the whole ledger fits, a question carries its totals but no list of
// earlier transactions.
func TestChat_OnlyTotalsWhenTheLedgerIsComplete(t *testing.T) {
	h := newHarness(t)
	h.configure("sk-chat-0006")
	h.seedLedger()
	h.fake.Deltas = []string{"Ogni mese."}
	res := h.stream("/v1/ai/analyses", h.runBody(chatBody("Quando pago Netflix?", nil)), nil)
	id := res.events[0].data["analysis_id"].(string)
	h.fake.Deltas = []string{"Sì."}
	h.stream("/v1/ai/analyses/"+id+"/messages", map[string]any{"content": "E l'affitto?"}, nil)
	d := h.do(http.MethodGet, "/v1/ai/analyses/"+id, nil)
	att, _ := d.body["messages"].([]any)[2].(map[string]any)["attachment"].(string)
	if d.body["options"].(map[string]any)["ledger_cutoff"] != nil || !strings.Contains(att, "### Parola \"affit\"") ||
		!strings.Contains(att, "Totale: uscite 3200.00") || strings.Contains(h.fake.LastRequest().Messages[2].Content, "corrispondono alla domanda") {
		t.Fatalf("unexpected attachment: %s", d.raw)
	}
}
