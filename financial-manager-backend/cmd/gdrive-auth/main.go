// Command gdrive-auth obtains the Google Drive refresh token the worker's
// backup job needs (GDRIVE_REFRESH_TOKEN). Run it once, on a machine with a
// browser — not on the server:
//
//	go run ./cmd/gdrive-auth -client-id ... -client-secret ...
//
// It performs the OAuth "loopback" flow for a Desktop app client: it listens
// on a random 127.0.0.1 port, prints a consent URL, receives Google's
// redirect, exchanges the code (with PKCE) and prints the refresh token.
// The client ID and secret can also come from GDRIVE_CLIENT_ID and
// GDRIVE_CLIENT_SECRET.
package main

import (
	"context"
	"crypto/rand"
	"encoding/hex"
	"errors"
	"flag"
	"fmt"
	"net"
	"net/http"
	"os"
	"time"

	"golang.org/x/oauth2"
	"golang.org/x/oauth2/google"

	"financial-manager-backend/internal/backup"
)

// consentTimeout is how long to wait for the user to finish the consent
// screen in the browser.
const consentTimeout = 5 * time.Minute

func main() {
	if err := run(); err != nil {
		fmt.Fprintln(os.Stderr, "error:", err)
		os.Exit(1)
	}
}

func run() error {
	clientID := flag.String("client-id", os.Getenv("GDRIVE_CLIENT_ID"), "OAuth client ID (Desktop app type)")
	clientSecret := flag.String("client-secret", os.Getenv("GDRIVE_CLIENT_SECRET"), "OAuth client secret")
	flag.Parse()
	if *clientID == "" || *clientSecret == "" {
		flag.Usage()
		return errors.New("-client-id and -client-secret are required")
	}

	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		return fmt.Errorf("listen for the OAuth redirect: %w", err)
	}
	defer listener.Close()

	cfg := &oauth2.Config{
		ClientID:     *clientID,
		ClientSecret: *clientSecret,
		Endpoint:     google.Endpoint,
		Scopes:       []string{backup.DriveScope},
		RedirectURL:  "http://" + listener.Addr().String() + "/",
	}

	state, err := randomState()
	if err != nil {
		return err
	}
	verifier := oauth2.GenerateVerifier()
	// AccessTypeOffline asks for a refresh token; ApprovalForce re-shows the
	// consent screen so Google issues a new one even if this client was
	// authorized before (it only returns one on consent).
	authURL := cfg.AuthCodeURL(state, oauth2.AccessTypeOffline, oauth2.ApprovalForce,
		oauth2.S256ChallengeOption(verifier))

	type result struct {
		code string
		err  error
	}
	results := make(chan result, 1)
	srv := &http.Server{
		ReadHeaderTimeout: 10 * time.Second,
		Handler: http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			q := r.URL.Query()
			// Also rejects the browser's /favicon.ico request.
			if q.Get("state") != state {
				http.Error(w, "state mismatch", http.StatusBadRequest)
				return
			}
			res := result{code: q.Get("code")}
			if e := q.Get("error"); e != "" {
				res = result{err: fmt.Errorf("authorization denied: %s", e)}
			}
			select {
			case results <- res:
			default: // a reload after the first redirect; already handled
			}
			fmt.Fprintln(w, "Done. You can close this tab and return to the terminal.")
		}),
	}
	go func() { _ = srv.Serve(listener) }()
	defer srv.Close()

	fmt.Println("Open this URL in a browser and sign in with the Google account that will hold the backups:")
	fmt.Println()
	fmt.Println(authURL)
	fmt.Println()
	fmt.Println("Waiting for the authorization...")

	var res result
	select {
	case res = <-results:
	case <-time.After(consentTimeout):
		return errors.New("timed out waiting for the authorization")
	}
	if res.err != nil {
		return res.err
	}

	ctx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()
	token, err := cfg.Exchange(ctx, res.code, oauth2.VerifierOption(verifier))
	if err != nil {
		return fmt.Errorf("exchange authorization code: %w", err)
	}
	if token.RefreshToken == "" {
		return errors.New("google returned no refresh token; revoke the app's access at https://myaccount.google.com/permissions and retry")
	}

	fmt.Println()
	fmt.Println("Add this line to the server's .env (keep it secret, it grants access to the backup files):")
	fmt.Println()
	fmt.Printf("GDRIVE_REFRESH_TOKEN=%s\n", token.RefreshToken)
	fmt.Println()
	fmt.Println("Reminder: if the OAuth consent screen is in \"Testing\" status, this token expires after 7 days.")
	fmt.Println("Publish the app (\"In production\") in Google Cloud Console to make it long-lived.")
	return nil
}

func randomState() (string, error) {
	b := make([]byte, 16)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	return hex.EncodeToString(b), nil
}
