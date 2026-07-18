package transactions

import (
	"testing"
	"time"

	"github.com/google/uuid"
)

func TestCursor_RoundTrip(t *testing.T) {
	occurredAt := time.Date(2026, 3, 15, 10, 30, 0, 0, time.UTC)
	id := uuid.New()

	cursor := encodeCursor(occurredAt, id)
	decodedTime, decodedID, err := decodeCursor(cursor)
	if err != nil {
		t.Fatalf("decodeCursor() error = %v", err)
	}

	if !decodedTime.Equal(occurredAt) {
		t.Errorf("decoded time = %v, want %v", decodedTime, occurredAt)
	}
	if decodedID != id {
		t.Errorf("decoded id = %v, want %v", decodedID, id)
	}
}

func TestDecodeCursor_RejectsGarbage(t *testing.T) {
	if _, _, err := decodeCursor("not-a-valid-cursor!!!"); err == nil {
		t.Error("expected an error for a malformed cursor")
	}
}
