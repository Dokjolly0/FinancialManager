package security

import (
	"testing"
	"time"

	"github.com/google/uuid"
)

func TestIssueAndParseAccessToken_RoundTrip(t *testing.T) {
	userID := uuid.New()
	sessionID := uuid.New()
	now := time.Now()

	token, err := IssueAccessToken("test-signing-key", userID, sessionID, 15*time.Minute, now)
	if err != nil {
		t.Fatalf("IssueAccessToken() error = %v", err)
	}

	claims, err := ParseAccessToken("test-signing-key", token)
	if err != nil {
		t.Fatalf("ParseAccessToken() error = %v", err)
	}

	if claims.UserID != userID {
		t.Errorf("UserID = %v, want %v", claims.UserID, userID)
	}
	if claims.SessionID != sessionID {
		t.Errorf("SessionID = %v, want %v", claims.SessionID, sessionID)
	}
}

func TestParseAccessToken_RejectsWrongSigningKey(t *testing.T) {
	token, err := IssueAccessToken("key-a", uuid.New(), uuid.New(), 15*time.Minute, time.Now())
	if err != nil {
		t.Fatal(err)
	}

	if _, err := ParseAccessToken("key-b", token); err == nil {
		t.Error("expected an error when parsing with the wrong signing key")
	}
}

func TestParseAccessToken_RejectsExpiredToken(t *testing.T) {
	past := time.Now().Add(-time.Hour)
	token, err := IssueAccessToken("test-signing-key", uuid.New(), uuid.New(), time.Minute, past)
	if err != nil {
		t.Fatal(err)
	}

	if _, err := ParseAccessToken("test-signing-key", token); err == nil {
		t.Error("expected an error when parsing an expired token")
	}
}
