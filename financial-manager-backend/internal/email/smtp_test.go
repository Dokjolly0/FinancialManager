package email

import (
	"bufio"
	"context"
	"io"
	"mime/quotedprintable"
	"net"
	"net/mail"
	"strconv"
	"strings"
	"testing"
	"time"
)

// fakeSMTP is a minimal SMTP server (no TLS, no auth) that records the
// envelope and the DATA of one message. starttls controls whether EHLO
// advertises STARTTLS (it is never actually performed).
type fakeSMTP struct {
	ln       net.Listener
	starttls bool
	got      chan received
}

type received struct {
	from, to string
	data     string
}

func newFakeSMTP(t *testing.T, starttls bool) *fakeSMTP {
	t.Helper()
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	f := &fakeSMTP{ln: ln, starttls: starttls, got: make(chan received, 1)}
	t.Cleanup(func() { ln.Close() })
	go f.serve()
	return f
}

func (f *fakeSMTP) port() int { return f.ln.Addr().(*net.TCPAddr).Port }

func (f *fakeSMTP) serve() {
	conn, err := f.ln.Accept()
	if err != nil {
		return
	}
	defer conn.Close()
	r := bufio.NewReader(conn)
	reply := func(s string) { io.WriteString(conn, s+"\r\n") }
	reply("220 fake ESMTP")
	var msg received
	for {
		line, err := r.ReadString('\n')
		if err != nil {
			return
		}
		cmd := strings.TrimRight(line, "\r\n")
		switch upper := strings.ToUpper(cmd); {
		case strings.HasPrefix(upper, "EHLO"):
			if f.starttls {
				reply("250-fake")
				reply("250 STARTTLS")
			} else {
				reply("250 fake")
			}
		case strings.HasPrefix(upper, "MAIL FROM:"):
			msg.from = strings.Trim(cmd[len("MAIL FROM:"):], "<> ")
			reply("250 ok")
		case strings.HasPrefix(upper, "RCPT TO:"):
			msg.to = strings.Trim(cmd[len("RCPT TO:"):], "<> ")
			reply("250 ok")
		case upper == "DATA":
			reply("354 go ahead")
			var b strings.Builder
			for {
				l, err := r.ReadString('\n')
				if err != nil {
					return
				}
				if l == ".\r\n" {
					break
				}
				b.WriteString(l)
			}
			msg.data = b.String()
			reply("250 queued")
			f.got <- msg
		case upper == "QUIT":
			reply("221 bye")
			return
		default:
			reply("502 not implemented")
		}
	}
}

func testSender(port int, mode TLSMode) SMTPSender {
	return SMTPSender{
		Host:    "127.0.0.1",
		Port:    port,
		From:    mail.Address{Name: "FinancialManager", Address: "noreply@example.com"},
		TLS:     mode,
		Timeout: 5 * time.Second,
	}
}

func TestSMTPSender_DeliversPlainTextUTF8Message(t *testing.T) {
	srv := newFakeSMTP(t, false)
	msg := PasswordResetMessage("mario@example.com", "https://fm.example.com/reset-password?token=abc", 30*time.Minute)

	if err := testSender(srv.port(), TLSNone).Send(context.Background(), msg); err != nil {
		t.Fatalf("Send: %v", err)
	}

	got := <-srv.got
	if got.from != "noreply@example.com" || got.to != "mario@example.com" {
		t.Errorf("envelope = %q -> %q", got.from, got.to)
	}
	head, body, ok := strings.Cut(got.data, "\r\n\r\n")
	if !ok {
		t.Fatalf("no header/body separator in %q", got.data)
	}
	for _, want := range []string{
		`From: "FinancialManager" <noreply@example.com>`,
		"To: <mario@example.com>",
		"Subject: Reimposta la password di FinancialManager",
		"Content-Type: text/plain; charset=UTF-8",
		"Content-Transfer-Encoding: quoted-printable",
		"MIME-Version: 1.0",
		"@example.com>\r\n", // Message-ID uses the sender's domain
	} {
		if !strings.Contains(head, want) {
			t.Errorf("headers missing %q:\n%s", want, head)
		}
	}
	decoded, err := io.ReadAll(quotedprintable.NewReader(strings.NewReader(body)))
	if err != nil {
		t.Fatal(err)
	}
	text := string(decoded)
	for _, want := range []string{"https://fm.example.com/reset-password?token=abc", "30 minuti", "può usare una volta sola"} {
		if !strings.Contains(text, want) {
			t.Errorf("body missing %q:\n%s", want, text)
		}
	}
	if strings.Contains(strings.ReplaceAll(text, "\r\n", ""), "\n") {
		t.Error("body has bare LF line endings; SMTP needs CRLF")
	}
}

func TestSMTPSender_EncodesNonASCIISubject(t *testing.T) {
	srv := newFakeSMTP(t, false)
	msg := Message{To: "a@example.com", Subject: "Città già verificata", Body: "ciao"}
	if err := testSender(srv.port(), TLSNone).Send(context.Background(), msg); err != nil {
		t.Fatalf("Send: %v", err)
	}
	if got := <-srv.got; !strings.Contains(got.data, "Subject: =?utf-8?q?") {
		t.Errorf("subject not RFC 2047 encoded:\n%s", got.data)
	}
}

func TestSMTPSender_RequiresSTARTTLSWhenConfigured(t *testing.T) {
	srv := newFakeSMTP(t, false) // does not advertise STARTTLS
	err := testSender(srv.port(), TLSStartTLS).Send(context.Background(), Message{To: "a@example.com", Subject: "s", Body: "b"})
	if err == nil || !strings.Contains(err.Error(), "STARTTLS") {
		t.Fatalf("expected a STARTTLS error, got %v", err)
	}
}

func TestSMTPSender_RejectsHeaderInjection(t *testing.T) {
	s := testSender(1, TLSNone)
	for _, msg := range []Message{
		{To: "a@example.com\r\nBcc: x@example.com", Subject: "s", Body: "b"},
		{To: "a@example.com", Subject: "s\r\nBcc: x@example.com", Body: "b"},
		{To: "not an address", Subject: "s", Body: "b"},
	} {
		if err := s.Send(context.Background(), msg); err == nil {
			t.Errorf("Send(%q, %q) = nil, want an error", msg.To, msg.Subject)
		}
	}
}

func TestSMTPSender_ConnectionErrorIsReported(t *testing.T) {
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		t.Fatal(err)
	}
	port := ln.Addr().(*net.TCPAddr).Port
	ln.Close() // nothing listens there anymore

	err = testSender(port, TLSNone).Send(context.Background(), Message{To: "a@example.com", Subject: "s", Body: "b"})
	if err == nil || !strings.Contains(err.Error(), strconv.Itoa(port)) {
		t.Fatalf("expected a connect error naming the port, got %v", err)
	}
}
