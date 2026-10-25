package ai_test

import (
	"net/http"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"

	"financial-manager-backend/internal/ai"
	"financial-manager-backend/internal/ai/prompt"
)

var testRuntime = map[string]any{
	"engine": "llama_cpp", "model_id": "qwen3-4b-q4_k_m", "display_name": "Qwen3 4B", "quantization": "Q4_K_M",
	"backend": "cpu", "context_tokens": 16384, "max_output_tokens": 1024, "app_version": "1.4.0",
}

func localPreviewBody() map[string]any {
	return map[string]any{
		"preset": "MONTHLY_CHECKUP",
		"period": map[string]any{"preset": "last_12_months"},
		"target": "on_device",
		"device": map[string]any{"context_tokens": 16384, "max_output_tokens": 1024},
		"options": map[string]any{
			"sections": []string{"monthly", "categories", "titles", "recurring"}, "profile": "compact",
		},
	}
}

// localRun previews on-device and returns a prepare body for it.
func (h *harness) localRun(runtime map[string]any) map[string]any {
	h.t.Helper()
	body := localPreviewBody()
	p := h.do(http.MethodPost, "/v1/ai/analyses/preview", body)
	h.mustStatus(p, http.StatusOK)
	body["data_fingerprint"] = p.body["data_fingerprint"]
	body["client_request_id"] = uuid.NewString()
	body["runtime"] = runtime
	return body
}

func (h *harness) acceptLocalConsent() {
	h.t.Helper()
	h.mustStatus(h.do(http.MethodPut, "/v1/ai/consent", map[string]any{"consent_version": ai.LocalConsentVersion, "scope": "on_device"}), http.StatusNoContent)
}

func resultPath(analysisID, messageID string) string {
	return "/v1/ai/analyses/" + analysisID + "/messages/" + messageID + "/result"
}

func TestLocal_FullFlowWithoutCloud(t *testing.T) {
	h := newHarness(t, harnessOptions{disabled: true, onDevice: true})
	h.seedLedger()

	s := h.do(http.MethodGet, "/v1/ai/settings", nil)
	h.mustStatus(s, http.StatusOK)
	local := s.body["consent"].(map[string]any)["on_device"].(map[string]any)
	if s.body["available"] != false || s.body["on_device_available"] != true || local["required"] != true || s.body["mode"] != "cloud" {
		t.Fatalf("settings = %s", s.raw)
	}
	if r := h.do(http.MethodPut, "/v1/ai/settings", map[string]any{"provider": "openai"}); r.errorCode() != "AI_DISABLED" {
		t.Fatalf("cloud settings without key = %d %s", r.status, r.raw)
	}
	if r := h.do(http.MethodPost, "/v1/ai/analyses/preview", localPreviewBody()); r.errorCode() != "AI_LOCAL_CONSENT_REQUIRED" {
		t.Fatalf("preview without local consent = %d %s", r.status, r.raw)
	}
	h.acceptLocalConsent()

	version := h.do(http.MethodGet, "/v1/ai/settings", nil).body["version"]
	mode := h.do(http.MethodPut, "/v1/ai/mode", map[string]any{"mode": "on_device", "local_model": "Qwen3 4B · Q4_K_M", "version": version})
	h.mustStatus(mode, http.StatusOK)
	if mode.body["mode"] != "on_device" || mode.body["local_model"] != "Qwen3 4B · Q4_K_M" {
		t.Fatalf("mode = %s", mode.raw)
	}
	if r := h.do(http.MethodPut, "/v1/ai/mode", map[string]any{"mode": "on_device", "version": version}); r.status != http.StatusConflict {
		t.Fatalf("stale mode version = %d", r.status)
	}
	if r := h.do(http.MethodPut, "/v1/ai/mode", map[string]any{"mode": "cloud", "version": mode.body["version"]}); r.errorCode() != "AI_DISABLED" {
		t.Fatalf("cloud mode without key = %d %s", r.status, r.raw)
	}

	// The preview targets the saved mode when no target is given.
	body := localPreviewBody()
	delete(body, "target")
	p := h.do(http.MethodPost, "/v1/ai/analyses/preview", body)
	h.mustStatus(p, http.StatusOK)
	fit := p.body["context_fit"].(map[string]any)
	if p.body["target"] != "on_device" || p.body["provider"] != "on_device" || p.body["model"] != "Qwen3 4B · Q4_K_M" ||
		p.body["estimated_cost"] != nil || fit["fits"] != true || fit["reserved_output_tokens"] != float64(1024) {
		t.Fatalf("on-device preview = %s", p.raw)
	}

	run := h.localRun(testRuntime)
	prep := h.do(http.MethodPost, "/v1/ai/local/analyses", run)
	h.mustStatus(prep, http.StatusCreated)
	msgs := prep.body["messages"].([]any)
	if len(msgs) != 1 || !strings.Contains(msgs[0].(map[string]any)["content"].(string), "<financial_data>") ||
		!strings.Contains(prep.body["system_prompt"].(string), "Usa SOLO i numeri presenti") ||
		prep.body["max_output_tokens"] != float64(1024) || prep.body["kind"] != "REPORT" || prep.body["deadline_at"] == nil {
		t.Fatalf("prepare = %s", prep.raw)
	}
	analysisID, messageID := prep.body["analysis_id"].(string), prep.body["message_id"].(string)

	// A retry while the report is pending resumes the same turn.
	again := h.do(http.MethodPost, "/v1/ai/local/analyses", run)
	h.mustStatus(again, http.StatusOK)
	if again.body["message_id"] != messageID {
		t.Fatalf("resume = %s", again.raw)
	}

	result := map[string]any{
		"content": "## Sintesi\nTutto bene.", "status": "COMPLETED", "input_tokens": 900, "output_tokens": 40,
		"truncated": false, "duration_ms": 95000,
	}
	r := h.do(http.MethodPut, resultPath(analysisID, messageID), result)
	h.mustStatus(r, http.StatusOK)
	if r.body["status"] != "COMPLETED" || r.body["duration_ms"] != float64(95000) {
		t.Fatalf("result = %s", r.raw)
	}
	// The outbox may resend the same result: accepted. A different one isn't.
	h.mustStatus(h.do(http.MethodPut, resultPath(analysisID, messageID), result), http.StatusOK)
	result["content"] = "altro"
	if r := h.do(http.MethodPut, resultPath(analysisID, messageID), result); r.errorCode() != "AI_MESSAGE_FINISHED" {
		t.Fatalf("different resend = %d %s", r.status, r.raw)
	}
	if r := h.do(http.MethodPost, "/v1/ai/local/analyses", run); r.errorCode() != "AI_ANALYSIS_EXISTS" {
		t.Fatalf("prepare after completion = %d %s", r.status, r.raw)
	}

	d := h.do(http.MethodGet, "/v1/ai/analyses/"+analysisID, nil)
	h.mustStatus(d, http.StatusOK)
	runtime := d.body["runtime"].(map[string]any)
	if d.body["provider"] != "on_device" || d.body["status"] != "COMPLETED" || d.body["cost"] != nil ||
		d.body["model"] != "Qwen3 4B · Q4_K_M · llama.cpp" || runtime["engine"] != "llama_cpp" || runtime["context_tokens"] != float64(16384) ||
		d.body["input_tokens"] != float64(900) || d.body["can_ask_follow_ups"] != true {
		t.Fatalf("detail = %s", d.raw)
	}
	report := d.body["messages"].([]any)[1].(map[string]any)
	if report["content"] != "## Sintesi\nTutto bene." || report["duration_ms"] != float64(95000) {
		t.Fatalf("report = %v", report)
	}
}

func TestLocal_Validation(t *testing.T) {
	h := newHarness(t, harnessOptions{disabled: true, onDevice: true})
	h.seedLedger()
	h.acceptLocalConsent()

	stale := h.localRun(testRuntime)
	stale["data_fingerprint"] = strings.Repeat("0", 64)
	if r := h.do(http.MethodPost, "/v1/ai/local/analyses", stale); r.errorCode() != "AI_DATA_CHANGED" {
		t.Fatalf("stale fingerprint = %d %s", r.status, r.raw)
	}

	small := map[string]any{}
	for k, v := range testRuntime {
		small[k] = v
	}
	small["context_tokens"], small["max_output_tokens"] = 600, 500
	if r := h.do(http.MethodPost, "/v1/ai/local/analyses", h.localRun(small)); r.errorCode() != "AI_LOCAL_CONTEXT_TOO_LONG" {
		t.Fatalf("too small a context = %d %s", r.status, r.raw)
	}

	bad := map[string]any{
		"engine": "tensorflow", "model_id": "bad id with spaces", "display_name": "", "quantization": "",
		"backend": "tpu", "context_tokens": 100, "max_output_tokens": 10,
	}
	r := h.do(http.MethodPost, "/v1/ai/local/analyses", h.localRun(bad))
	for _, field := range []string{"runtime.engine", "runtime.model_id", "runtime.display_name", "runtime.quantization", "runtime.backend", "runtime.context_tokens"} {
		if r.fieldError(field) == "" {
			t.Errorf("missing %s error: %s", field, r.raw)
		}
	}

	prep := h.do(http.MethodPost, "/v1/ai/local/analyses", h.localRun(testRuntime))
	h.mustStatus(prep, http.StatusCreated)
	path := resultPath(prep.body["analysis_id"].(string), prep.body["message_id"].(string))
	huge := map[string]any{"content": strings.Repeat("è", 110_000), "status": "COMPLETED"} // 220 KB of UTF-8
	if r := h.do(http.MethodPut, path, huge); r.errorCode() != "AI_ANSWER_TOO_LONG" {
		t.Fatalf("too long = %d %s", r.status, r.raw)
	}
	if r := h.do(http.MethodPut, path, map[string]any{"content": "x", "status": "DONE"}); r.fieldError("status") == "" {
		t.Fatalf("bad status = %s", r.raw)
	}
	failed := h.do(http.MethodPut, path, map[string]any{"content": "parziale", "status": "FAILED", "error_code": "SOMETHING_ELSE"})
	h.mustStatus(failed, http.StatusOK)
	if failed.body["error_code"] != "AI_LOCAL_ENGINE_ERROR" {
		t.Fatalf("unknown error code must be normalized: %s", failed.raw)
	}
	d := h.do(http.MethodGet, "/v1/ai/analyses/"+prep.body["analysis_id"].(string), nil)
	if d.body["status"] != "FAILED" || d.body["error_code"] != "AI_LOCAL_ENGINE_ERROR" {
		t.Fatalf("failed analysis = %s", d.raw)
	}
}

func TestLocal_FollowUpsAndCloudSeparation(t *testing.T) {
	h := newHarness(t, harnessOptions{onDevice: true})
	h.configure("sk-local-0001")
	h.seedLedger()
	h.acceptLocalConsent()

	prep := h.do(http.MethodPost, "/v1/ai/local/analyses", h.localRun(testRuntime))
	h.mustStatus(prep, http.StatusCreated)
	id := prep.body["analysis_id"].(string)
	h.mustStatus(h.do(http.MethodPut, resultPath(id, prep.body["message_id"].(string)),
		map[string]any{"content": "Report locale.", "status": "COMPLETED"}), http.StatusOK)

	q := h.do(http.MethodPost, "/v1/ai/local/analyses/"+id+"/messages", map[string]any{"content": "  Perché?  "})
	h.mustStatus(q, http.StatusCreated)
	msgs := q.body["messages"].([]any)
	if len(msgs) != 3 || msgs[1].(map[string]any)["content"] != "Report locale." ||
		msgs[2].(map[string]any)["content"] != prompt.FollowUpQuestion("Perché?", prompt.LangIT) ||
		q.body["kind"] != "ANSWER" || q.body["question_id"] == nil {
		t.Fatalf("local follow-up = %s", q.raw)
	}
	// The phone runs the answer with the follow-up rules, as the cloud does.
	if q.body["system_prompt"] != prompt.WithFollowUpRules(prep.body["system_prompt"].(string), prompt.LangIT) {
		t.Fatalf("local follow-up system prompt = %q", q.body["system_prompt"])
	}
	// While that answer is pending, another question waits.
	if r := h.do(http.MethodPost, "/v1/ai/local/analyses/"+id+"/messages", map[string]any{"content": "E poi?"}); r.errorCode() != "AI_STREAM_IN_PROGRESS" {
		t.Fatalf("second pending question = %d %s", r.status, r.raw)
	}
	h.mustStatus(h.do(http.MethodPut, resultPath(id, q.body["message_id"].(string)),
		map[string]any{"content": "Per l'affitto.", "status": "COMPLETED"}), http.StatusOK)

	// A local analysis never continues on the cloud provider.
	if r := h.do(http.MethodPost, "/v1/ai/analyses/"+id+"/messages", map[string]any{"content": "Cloud?"}); r.errorCode() != "AI_ANALYSIS_ON_DEVICE" {
		t.Fatalf("cloud follow-up on local = %d %s", r.status, r.raw)
	}

	// And a cloud analysis doesn't take local turns or results.
	h.fake.Deltas = []string{"Report cloud."}
	res := h.stream("/v1/ai/analyses", h.runBody(previewBody(nil)), nil)
	cloudID := res.events[0].data["analysis_id"].(string)
	if r := h.do(http.MethodPost, "/v1/ai/local/analyses/"+cloudID+"/messages", map[string]any{"content": "?"}); r.errorCode() != "AI_ANALYSIS_NOT_ON_DEVICE" {
		t.Fatalf("local follow-up on cloud = %d %s", r.status, r.raw)
	}
	if r := h.do(http.MethodPut, resultPath(cloudID, res.events[0].data["message_id"].(string)), map[string]any{"content": "x", "status": "COMPLETED"}); r.errorCode() != "AI_ANALYSIS_NOT_ON_DEVICE" {
		t.Fatalf("local result on cloud = %d %s", r.status, r.raw)
	}

	// Revoking the local consent blocks new local turns only.
	h.mustStatus(h.do(http.MethodDelete, "/v1/ai/consent?scope=on_device", nil), http.StatusNoContent)
	if r := h.do(http.MethodPost, "/v1/ai/local/analyses/"+id+"/messages", map[string]any{"content": "?"}); r.errorCode() != "AI_LOCAL_CONSENT_REQUIRED" {
		t.Fatalf("after revoke = %d %s", r.status, r.raw)
	}
	if consent := h.do(http.MethodGet, "/v1/ai/settings", nil).body["consent"].(map[string]any); consent["required"] != false {
		t.Fatal("revoking the local consent must not touch the cloud one")
	}
}

func TestLocal_StaleWindowIsLonger(t *testing.T) {
	offset := time.Duration(0)
	h := newHarness(t, harnessOptions{disabled: true, onDevice: true, clockOffset: &offset})
	h.seedLedger()
	h.acceptLocalConsent()
	prep := h.do(http.MethodPost, "/v1/ai/local/analyses", h.localRun(testRuntime))
	h.mustStatus(prep, http.StatusCreated)
	id := prep.body["analysis_id"].(string)

	offset = 10 * time.Minute // past the 6-minute cloud window
	if d := h.do(http.MethodGet, "/v1/ai/analyses/"+id, nil); d.body["status"] != "STREAMING" {
		t.Fatalf("after 10 minutes = %v", d.body["status"])
	}
	offset = 32 * time.Minute // past AI_LOCAL_MAX_DURATION + grace
	d := h.do(http.MethodGet, "/v1/ai/analyses/"+id, nil)
	if d.body["status"] != "FAILED" || d.body["error_code"] != "AI_STREAM_INTERRUPTED" {
		t.Fatalf("after 32 minutes = %v %v", d.body["status"], d.body["error_code"])
	}
	// A late result is still accepted: the phone did the work.
	h.mustStatus(h.do(http.MethodPut, resultPath(id, prep.body["message_id"].(string)),
		map[string]any{"content": "In ritardo.", "status": "COMPLETED"}), http.StatusOK)
	if d := h.do(http.MethodGet, "/v1/ai/analyses/"+id, nil); d.body["status"] != "COMPLETED" {
		t.Fatalf("after a late result = %v", d.body["status"])
	}
}

func TestLocal_DisabledOnServer(t *testing.T) {
	h := newHarness(t)
	h.configure("sk-local-0002")
	if r := h.do(http.MethodPut, "/v1/ai/consent", map[string]any{"consent_version": 1, "scope": "on_device"}); r.errorCode() != "AI_ON_DEVICE_DISABLED" {
		t.Fatalf("local consent when disabled = %d %s", r.status, r.raw)
	}
	if r := h.do(http.MethodPut, "/v1/ai/mode", map[string]any{"mode": "on_device", "version": 1}); r.errorCode() != "AI_ON_DEVICE_DISABLED" {
		t.Fatalf("local mode when disabled = %d %s", r.status, r.raw)
	}
	if s := h.do(http.MethodGet, "/v1/ai/settings", nil); s.body["on_device_available"] != false {
		t.Fatalf("settings = %s", s.raw)
	}
}
