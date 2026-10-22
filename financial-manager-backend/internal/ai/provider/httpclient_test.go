package provider

import (
	"context"
	"errors"
	"io"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

func TestValidateBaseURL(t *testing.T) {
	strict := BaseURLPolicy{}
	lan := BaseURLPolicy{AllowPrivate: true}
	allowlist := BaseURLPolicy{AllowedHosts: []string{"api.mistral.ai"}}

	cases := []struct {
		name    string
		policy  BaseURLPolicy
		in      string
		want    string
		wantErr error
	}{
		{"public https", strict, "https://api.mistral.ai/v1/", "https://api.mistral.ai/v1", nil},
		{"port kept", strict, "https://llm.example.com:8443/v1", "https://llm.example.com:8443/v1", nil},
		{"http refused", strict, "http://api.mistral.ai/v1", "", ErrBaseURLInvalid},
		{"no scheme", strict, "api.mistral.ai/v1", "", ErrBaseURLInvalid},
		{"ftp", strict, "ftp://api.mistral.ai", "", ErrBaseURLInvalid},
		{"userinfo", strict, "https://user:pass@api.mistral.ai/v1", "", ErrBaseURLInvalid},
		{"query", strict, "https://api.mistral.ai/v1?x=1", "", ErrBaseURLInvalid},
		{"fragment", strict, "https://api.mistral.ai/v1#x", "", ErrBaseURLInvalid},
		{"localhost", strict, "https://localhost:11434/v1", "", ErrBaseURLNotAllowed},
		{"loopback ip", strict, "https://127.0.0.1/v1", "", ErrBaseURLNotAllowed},
		{"ipv6 loopback", strict, "https://[::1]/v1", "", ErrBaseURLNotAllowed},
		{"private 10/8", strict, "https://10.0.0.1/v1", "", ErrBaseURLNotAllowed},
		{"private 192.168", strict, "https://192.168.1.20/v1", "", ErrBaseURLNotAllowed},
		{"cloud metadata", strict, "https://169.254.169.254/latest", "", ErrBaseURLNotAllowed},
		{"cgnat", strict, "https://100.64.1.1/v1", "", ErrBaseURLNotAllowed},
		{"ula ipv6", strict, "https://[fd00::1]/v1", "", ErrBaseURLNotAllowed},
		{"ipv4-mapped ipv6", strict, "https://[::ffff:10.0.0.1]/v1", "", ErrBaseURLNotAllowed},
		{"lan allowed with flag", lan, "http://192.168.1.20:11434/v1", "http://192.168.1.20:11434/v1", nil},
		{"allowlist hit", allowlist, "https://API.mistral.ai/v1", "https://API.mistral.ai/v1", nil},
		{"allowlist miss", allowlist, "https://openrouter.ai/api/v1", "", ErrBaseURLNotAllowed},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			got, err := c.policy.ValidateBaseURL(c.in)
			if !errors.Is(err, c.wantErr) {
				t.Fatalf("err = %v, want %v", err, c.wantErr)
			}
			if got != c.want {
				t.Fatalf("got %q, want %q", got, c.want)
			}
		})
	}
}

// A hostname passes static validation but resolves to loopback: the dial
// check must still refuse the connection (this is also what defeats DNS
// rebinding). "localtest.me" would need DNS; the httptest server's
// 127.0.0.1 address exercises the same dial-time check.
func TestHTTPClient_BlocksPrivateAddressAtDialTime(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		_, _ = io.WriteString(w, "should not be reached")
	}))
	defer srv.Close()

	client := NewHTTPClient(BaseURLPolicy{}, time.Second)
	req, _ := http.NewRequestWithContext(context.Background(), http.MethodGet, srv.URL, nil)
	_, err := client.Do(req)
	var blocked *blockedAddressError
	if !errors.As(err, &blocked) || !errors.Is(err, ErrBaseURLNotAllowed) {
		t.Fatalf("err = %v, want a blocked address error", err)
	}

	permissive := NewHTTPClient(BaseURLPolicy{AllowPrivate: true}, time.Second)
	resp, err := permissive.Do(req)
	if err != nil {
		t.Fatalf("permissive client: %v", err)
	}
	resp.Body.Close()
}

func TestHTTPClient_DoesNotFollowRedirects(t *testing.T) {
	srv := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		http.Redirect(w, r, "http://169.254.169.254/latest/meta-data", http.StatusFound)
	}))
	defer srv.Close()

	f := NewHTTPFactory(BaseURLPolicy{AllowPrivate: true}, time.Second).WithNativeBaseURL(KindOpenAI, srv.URL)
	p, _ := f.New(Config{Kind: KindOpenAI, APIKey: "k"})
	_, err := p.ListModels(context.Background())
	var pe *Error
	if !errors.As(err, &pe) || pe.Status != http.StatusFound {
		t.Fatalf("err = %v, want the 302 surfaced as an error", err)
	}
}
