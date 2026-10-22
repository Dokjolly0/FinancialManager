package httpserver

import (
	"net"
	"net/http"
	"net/netip"
	"strings"
)

// RealIP rewrites r.RemoteAddr to the client address reported by a trusted
// reverse proxy (plan.md section 19.5). X-Forwarded-For is only read when
// the direct peer is inside one of the trusted prefixes, and then walked
// from the right, skipping trusted hops: the first untrusted address is the
// client. Entries further left were written by the client itself and can be
// spoofed, so they are never used. With no trusted prefixes (the default,
// TRUSTED_PROXY_CIDRS unset) the middleware is a no-op and RemoteAddr stays
// the TCP peer.
func RealIP(trusted []netip.Prefix) func(http.Handler) http.Handler {
	isTrusted := func(addr netip.Addr) bool {
		addr = addr.Unmap()
		for _, p := range trusted {
			if p.Contains(addr) {
				return true
			}
		}
		return false
	}

	return func(next http.Handler) http.Handler {
		if len(trusted) == 0 {
			return next
		}
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if peer, ok := remoteAddr(r.RemoteAddr); ok && isTrusted(peer) {
				if client, ok := forwardedClient(r.Header.Values("X-Forwarded-For"), isTrusted); ok {
					r.RemoteAddr = net.JoinHostPort(client.String(), "0")
				}
			}
			next.ServeHTTP(w, r)
		})
	}
}

func remoteAddr(hostPort string) (netip.Addr, bool) {
	if ap, err := netip.ParseAddrPort(hostPort); err == nil {
		return ap.Addr(), true
	}
	addr, err := netip.ParseAddr(hostPort)
	return addr, err == nil
}

// forwardedClient returns the rightmost untrusted address in the
// X-Forwarded-For chain. A malformed hop stops the walk: nothing to its
// left can be trusted either.
func forwardedClient(headers []string, isTrusted func(netip.Addr) bool) (netip.Addr, bool) {
	var hops []string
	for _, h := range headers {
		hops = append(hops, strings.Split(h, ",")...)
	}
	for i := len(hops) - 1; i >= 0; i-- {
		addr, err := netip.ParseAddr(strings.TrimSpace(hops[i]))
		if err != nil {
			return netip.Addr{}, false
		}
		if !isTrusted(addr) {
			return addr.Unmap(), true
		}
	}
	return netip.Addr{}, false
}
