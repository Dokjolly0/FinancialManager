package provider

import (
	"errors"
	"fmt"
	"net"
	"net/http"
	"net/netip"
	"net/url"
	"strings"
	"syscall"
	"time"
)

// Base URL validation errors, mapped to field codes by the ai package.
var (
	ErrBaseURLInvalid    = errors.New("base URL is not a valid https URL")
	ErrBaseURLNotAllowed = errors.New("base URL points to a host that is not allowed")
)

// BaseURLPolicy guards the server against SSRF through user-supplied
// OpenAI-compatible base URLs (plan.md section 32.5).
type BaseURLPolicy struct {
	// AllowPrivate allows plain http and private, loopback and link-local
	// addresses (a LAN Ollama). Off on any server reachable by others.
	AllowPrivate bool
	// AllowedHosts, when non-empty, is an exact allowlist of hostnames.
	AllowedHosts []string
}

// ValidateBaseURL checks a user-supplied base URL and returns it without a
// trailing slash. The resolved address is checked again at connect time
// (see NewHTTPClient), which also defeats DNS rebinding.
func (p BaseURLPolicy) ValidateBaseURL(raw string) (string, error) {
	u, err := url.Parse(strings.TrimSpace(raw))
	if err != nil || u.Host == "" || u.Opaque != "" {
		return "", ErrBaseURLInvalid
	}
	switch u.Scheme {
	case "https":
	case "http":
		if !p.AllowPrivate {
			return "", ErrBaseURLInvalid
		}
	default:
		return "", ErrBaseURLInvalid
	}
	if u.User != nil || u.Fragment != "" || u.RawQuery != "" {
		return "", ErrBaseURLInvalid
	}

	host := strings.ToLower(u.Hostname())
	if len(p.AllowedHosts) > 0 {
		allowed := false
		for _, h := range p.AllowedHosts {
			if strings.EqualFold(h, host) {
				allowed = true
				break
			}
		}
		if !allowed {
			return "", ErrBaseURLNotAllowed
		}
	}
	if !p.AllowPrivate {
		if host == "localhost" || strings.HasSuffix(host, ".localhost") || strings.HasSuffix(host, ".internal") {
			return "", ErrBaseURLNotAllowed
		}
		if addr, err := netip.ParseAddr(host); err == nil && isBlockedAddr(addr) {
			return "", ErrBaseURLNotAllowed
		}
	}

	u.Path = strings.TrimRight(u.Path, "/")
	return u.String(), nil
}

// blockedRanges lists special-purpose networks beyond what netip's helpers
// already classify (loopback, private, link-local, multicast, unspecified).
var blockedRanges = []netip.Prefix{
	netip.MustParsePrefix("0.0.0.0/8"),
	netip.MustParsePrefix("100.64.0.0/10"), // carrier-grade NAT
	netip.MustParsePrefix("192.0.0.0/24"),
	netip.MustParsePrefix("198.18.0.0/15"), // benchmarking
	netip.MustParsePrefix("240.0.0.0/4"),
	netip.MustParsePrefix("64:ff9b::/96"), // NAT64 can embed a private IPv4
	netip.MustParsePrefix("2001:db8::/32"),
}

func isBlockedAddr(addr netip.Addr) bool {
	addr = addr.Unmap()
	if addr.IsLoopback() || addr.IsPrivate() || addr.IsLinkLocalUnicast() || addr.IsLinkLocalMulticast() ||
		addr.IsInterfaceLocalMulticast() || addr.IsMulticast() || addr.IsUnspecified() {
		return true
	}
	for _, p := range blockedRanges {
		if p.Contains(addr) {
			return true
		}
	}
	return false
}

// blockedAddressError is returned when a connection would reach a blocked
// address after DNS resolution.
type blockedAddressError struct{ addr string }

func (e *blockedAddressError) Error() string {
	return fmt.Sprintf("connection to %s blocked: private or reserved address", e.addr)
}

func (e *blockedAddressError) Unwrap() error { return ErrBaseURLNotAllowed }

// dialControl runs after DNS resolution, on the exact address about to be
// dialled, so a hostname that resolves (or re-resolves) to a private
// address is refused.
func (p BaseURLPolicy) dialControl(_, address string, _ syscall.RawConn) error {
	if p.AllowPrivate {
		return nil
	}
	host, _, err := net.SplitHostPort(address)
	if err != nil {
		return &blockedAddressError{addr: address}
	}
	addr, err := netip.ParseAddr(host)
	if err != nil || isBlockedAddr(addr) {
		return &blockedAddressError{addr: host}
	}
	return nil
}

// NewHTTPClient builds the client shared by every adapter: no redirects
// (a redirect could leave the validated host), no proxy from the
// environment (the dial check must see the real destination), and no
// overall timeout, since streams are bounded by their context instead.
func NewHTTPClient(policy BaseURLPolicy, responseHeaderTimeout time.Duration) *http.Client {
	dialer := &net.Dialer{
		Timeout:   10 * time.Second,
		KeepAlive: 30 * time.Second,
		Control:   policy.dialControl,
	}
	transport := &http.Transport{
		DialContext:           dialer.DialContext,
		ForceAttemptHTTP2:     true,
		TLSHandshakeTimeout:   10 * time.Second,
		ResponseHeaderTimeout: responseHeaderTimeout,
		MaxIdleConns:          20,
		IdleConnTimeout:       90 * time.Second,
	}
	return &http.Client{
		Transport: transport,
		CheckRedirect: func(*http.Request, []*http.Request) error {
			return http.ErrUseLastResponse
		},
	}
}
