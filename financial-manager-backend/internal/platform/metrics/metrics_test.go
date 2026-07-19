package metrics

import (
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/prometheus/client_golang/prometheus/testutil"
)

func TestHandler_ServesExpositionFormat(t *testing.T) {
	RateLimitTriggered.WithLabelValues("test-scope").Inc()

	rec := httptest.NewRecorder()
	req := httptest.NewRequest("GET", "/metrics", nil)
	Handler().ServeHTTP(rec, req)

	if rec.Code != 200 {
		t.Fatalf("expected 200, got %d", rec.Code)
	}
	body := rec.Body.String()
	if !strings.Contains(body, "financialmanager_rate_limit_triggered_total") {
		t.Fatalf("expected exposition body to contain the counter name, got: %s", body)
	}
}

func TestReportCacheResult_CountsByLabel(t *testing.T) {
	before := testutil.ToFloat64(ReportCacheResult.WithLabelValues("hit"))
	ReportCacheResult.WithLabelValues("hit").Inc()
	after := testutil.ToFloat64(ReportCacheResult.WithLabelValues("hit"))

	if after != before+1 {
		t.Fatalf("expected hit counter to increase by 1, got before=%v after=%v", before, after)
	}
}
