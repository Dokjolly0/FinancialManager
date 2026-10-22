package httpserver

import (
	"net/http"
	"net/http/httptest"
	"net/netip"
	"testing"
)

func TestRealIP(t *testing.T) {
	trusted := []netip.Prefix{netip.MustParsePrefix("172.16.0.0/12"), netip.MustParsePrefix("10.0.0.1/32")}

	cases := []struct {
		name       string
		trusted    bool
		remoteAddr string
		xff        []string
		want       string
	}{
		{"untrusted peer keeps its address", true, "203.0.113.7:5555", []string{"198.51.100.1"}, "203.0.113.7:5555"},
		{"trusted peer without header", true, "172.18.0.1:40000", nil, "172.18.0.1:40000"},
		{"trusted peer with client", true, "172.18.0.1:40000", []string{"198.51.100.1"}, "198.51.100.1:0"},
		{"spoofed left entry is ignored", true, "172.18.0.1:40000", []string{"1.2.3.4, 198.51.100.1"}, "198.51.100.1:0"},
		{"trusted hops are skipped", true, "172.18.0.1:40000", []string{"198.51.100.1, 10.0.0.1"}, "198.51.100.1:0"},
		{"several header lines", true, "172.18.0.1:40000", []string{"1.2.3.4", "198.51.100.1"}, "198.51.100.1:0"},
		{"IPv6 client", true, "172.18.0.1:40000", []string{"2001:db8::1"}, "[2001:db8::1]:0"},
		{"malformed hop", true, "172.18.0.1:40000", []string{"198.51.100.1, garbage"}, "172.18.0.1:40000"},
		{"only trusted hops", true, "172.18.0.1:40000", []string{"10.0.0.1"}, "172.18.0.1:40000"},
		{"no trusted prefixes", false, "172.18.0.1:40000", []string{"198.51.100.1"}, "172.18.0.1:40000"},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			prefixes := trusted
			if !tc.trusted {
				prefixes = nil
			}
			var got string
			handler := RealIP(prefixes)(http.HandlerFunc(func(_ http.ResponseWriter, r *http.Request) {
				got = r.RemoteAddr
			}))
			req := httptest.NewRequest(http.MethodGet, "/", nil)
			req.RemoteAddr = tc.remoteAddr
			for _, v := range tc.xff {
				req.Header.Add("X-Forwarded-For", v)
			}
			handler.ServeHTTP(httptest.NewRecorder(), req)
			if got != tc.want {
				t.Fatalf("RemoteAddr = %q, want %q", got, tc.want)
			}
		})
	}
}
