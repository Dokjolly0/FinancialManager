package email

import (
	"strings"
	"testing"
	"time"
)

func TestMessages_CarryLinkAndValidity(t *testing.T) {
	reset := PasswordResetMessage("a@example.com", "https://x/reset-password?token=t1", 30*time.Minute)
	verify := EmailVerificationMessage("a@example.com", "https://x/verify-email?token=t2", 24*time.Hour)

	for _, tc := range []struct {
		msg  Message
		want []string
	}{
		{reset, []string{"https://x/reset-password?token=t1", "30 minuti", "ignora questa email"}},
		{verify, []string{"https://x/verify-email?token=t2", "24 ore", "ignora questa email"}},
	} {
		if tc.msg.To != "a@example.com" || tc.msg.Subject == "" {
			t.Errorf("message %+v: missing recipient or subject", tc.msg)
		}
		for _, w := range tc.want {
			if !strings.Contains(tc.msg.Body, w) {
				t.Errorf("%q: body missing %q", tc.msg.Subject, w)
			}
		}
	}
}

func TestItalianDuration(t *testing.T) {
	for d, want := range map[time.Duration]string{
		time.Minute:      "1 minuto",
		30 * time.Minute: "30 minuti",
		90 * time.Minute: "90 minuti",
		time.Hour:        "1 ora",
		24 * time.Hour:   "24 ore",
	} {
		if got := italianDuration(d); got != want {
			t.Errorf("italianDuration(%v) = %q, want %q", d, got, want)
		}
	}
}
