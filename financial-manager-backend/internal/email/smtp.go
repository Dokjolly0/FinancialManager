package email

import (
	"bytes"
	"context"
	"crypto/rand"
	"crypto/tls"
	"encoding/hex"
	"errors"
	"fmt"
	"mime"
	"mime/quotedprintable"
	"net"
	"net/mail"
	"net/smtp"
	"strconv"
	"strings"
	"time"
)

// TLSMode is how the connection to the SMTP server is protected.
type TLSMode string

const (
	// TLSStartTLS connects in plain text and upgrades with STARTTLS before
	// authenticating (port 587). The upgrade is mandatory: a server that
	// doesn't offer it is an error, never a silent plain-text fallback.
	TLSStartTLS TLSMode = "starttls"
	// TLSImplicit speaks TLS from the first byte (port 465).
	TLSImplicit TLSMode = "tls"
	// TLSNone never encrypts. Only for a local test server (Mailpit);
	// config refuses it in production.
	TLSNone TLSMode = "none"
)

const defaultSMTPTimeout = 30 * time.Second

// SMTPSender delivers each message over a new SMTP connection: the API
// sends a handful of emails a day, not worth a connection pool.
type SMTPSender struct {
	Host     string
	Port     int
	Username string // empty: no authentication
	Password string
	From     mail.Address
	TLS      TLSMode
	// Timeout bounds the whole exchange (dial to QUIT); 30s when zero.
	Timeout time.Duration
}

func (s SMTPSender) Send(ctx context.Context, msg Message) error {
	if strings.ContainsAny(msg.To, "\r\n") || strings.ContainsAny(msg.Subject, "\r\n") {
		return errors.New("email: header values must not contain line breaks")
	}
	if _, err := mail.ParseAddress(msg.To); err != nil {
		return fmt.Errorf("email: invalid recipient: %w", err)
	}
	data, err := s.build(msg, time.Now())
	if err != nil {
		return err
	}

	timeout := s.Timeout
	if timeout <= 0 {
		timeout = defaultSMTPTimeout
	}
	deadline := time.Now().Add(timeout)
	if d, ok := ctx.Deadline(); ok && d.Before(deadline) {
		deadline = d
	}

	addr := net.JoinHostPort(s.Host, strconv.Itoa(s.Port))
	tlsConfig := &tls.Config{ServerName: s.Host, MinVersion: tls.VersionTLS12}
	dialer := &tls.Dialer{NetDialer: &net.Dialer{Deadline: deadline}, Config: tlsConfig}
	var conn net.Conn
	if s.TLS == TLSImplicit {
		conn, err = dialer.DialContext(ctx, "tcp", addr)
	} else {
		conn, err = dialer.NetDialer.DialContext(ctx, "tcp", addr)
	}
	if err != nil {
		return fmt.Errorf("email: connect %s: %w", addr, err)
	}
	if err := conn.SetDeadline(deadline); err != nil {
		conn.Close()
		return err
	}

	c, err := smtp.NewClient(conn, s.Host)
	if err != nil {
		conn.Close()
		return fmt.Errorf("email: smtp greeting: %w", err)
	}
	defer c.Close()

	if s.TLS == TLSStartTLS {
		if ok, _ := c.Extension("STARTTLS"); !ok {
			return errors.New("email: server does not offer STARTTLS (set SMTP_TLS=tls for port 465)")
		}
		if err := c.StartTLS(tlsConfig); err != nil {
			return fmt.Errorf("email: starttls: %w", err)
		}
	}
	if s.Username != "" {
		// PlainAuth refuses to send the password over a connection that
		// isn't TLS (except to localhost).
		if err := c.Auth(smtp.PlainAuth("", s.Username, s.Password, s.Host)); err != nil {
			return fmt.Errorf("email: auth: %w", err)
		}
	}
	if err := c.Mail(s.From.Address); err != nil {
		return fmt.Errorf("email: MAIL FROM: %w", err)
	}
	if err := c.Rcpt(msg.To); err != nil {
		return fmt.Errorf("email: RCPT TO: %w", err)
	}
	w, err := c.Data()
	if err != nil {
		return fmt.Errorf("email: DATA: %w", err)
	}
	if _, err := w.Write(data); err != nil {
		return fmt.Errorf("email: write message: %w", err)
	}
	if err := w.Close(); err != nil {
		return fmt.Errorf("email: message rejected: %w", err)
	}
	return c.Quit()
}

// build renders msg as a plain-text UTF-8 message (RFC 5322), body in
// quoted-printable so accented letters survive any relay.
func (s SMTPSender) build(msg Message, now time.Time) ([]byte, error) {
	var id [16]byte
	if _, err := rand.Read(id[:]); err != nil {
		return nil, err
	}
	domain := "localhost"
	if at := strings.LastIndexByte(s.From.Address, '@'); at >= 0 {
		domain = s.From.Address[at+1:]
	}

	var b bytes.Buffer
	header := func(name, value string) { fmt.Fprintf(&b, "%s: %s\r\n", name, value) }
	header("From", s.From.String())
	header("To", (&mail.Address{Address: msg.To}).String())
	header("Subject", mime.QEncoding.Encode("utf-8", msg.Subject))
	header("Date", now.Format(time.RFC1123Z))
	header("Message-ID", fmt.Sprintf("<%s@%s>", hex.EncodeToString(id[:]), domain))
	header("MIME-Version", "1.0")
	header("Content-Type", "text/plain; charset=UTF-8")
	header("Content-Transfer-Encoding", "quoted-printable")
	b.WriteString("\r\n")

	qp := quotedprintable.NewWriter(&b)
	body := strings.ReplaceAll(strings.ReplaceAll(msg.Body, "\r\n", "\n"), "\n", "\r\n")
	if _, err := qp.Write([]byte(body)); err != nil {
		return nil, err
	}
	if err := qp.Close(); err != nil {
		return nil, err
	}
	return b.Bytes(), nil
}
