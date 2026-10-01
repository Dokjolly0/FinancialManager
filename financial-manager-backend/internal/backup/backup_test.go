package backup

import (
	"bytes"
	"context"
	"errors"
	"os"
	"testing"
	"time"
)

type stepClock struct{ t time.Time }

func (c *stepClock) Now() time.Time { return c.t }

const testKey = "test passphrase"

func newTestService(t *testing.T, clk *stepClock, dest *memDestination) *Service {
	t.Helper()
	return NewService(Deps{
		Config: Config{
			DatabaseURL:     "postgres://unused",
			EncryptionKey:   testKey,
			Interval:        24 * time.Hour,
			RetentionDays:   3,
			RetentionMonths: 0,
			IncludeMedia:    true,
		},
		Dest:  dest,
		Media: fakeObjects{"users/a/1.jpg": []byte("img")},
		Clock: clk,
		Dump: func(_ context.Context, _, path string) error {
			return os.WriteFile(path, []byte("dump at "+clk.Now().Format(time.RFC3339)), 0o600)
		},
	})
}

func TestService_RunUploadsEncryptedDumpAndMedia(t *testing.T) {
	clk := &stepClock{t: time.Date(2026, 10, 1, 3, 0, 0, 0, time.UTC)}
	dest := newMemDestination(clk.Now)
	svc := newTestService(t, clk, dest)

	res, err := svc.RunIfDue(context.Background())
	if err != nil {
		t.Fatal(err)
	}
	if !res.Ran || res.MediaStats.Objects != 1 {
		t.Fatalf("result = %+v", res)
	}

	dumps := dest.byName(dbDumpName(clk.t))
	if len(dumps) != 1 {
		t.Fatalf("expected one database dump named %s", dbDumpName(clk.t))
	}
	if !bytes.Equal(decrypt(t, dumps[0], testKey), []byte("dump at 2026-10-01T03:00:00Z")) {
		t.Error("uploaded dump doesn't decrypt to the original")
	}
	assertMedia(t, dest, string(dest.byName(mediaLatestName)[0]), "")
}

func TestService_RunIfDueSkipsFreshBackup(t *testing.T) {
	clk := &stepClock{t: time.Date(2026, 10, 1, 3, 0, 0, 0, time.UTC)}
	dest := newMemDestination(clk.Now)
	svc := newTestService(t, clk, dest)
	ctx := context.Background()

	if _, err := svc.RunIfDue(ctx); err != nil {
		t.Fatal(err)
	}

	clk.t = clk.t.Add(23 * time.Hour)
	res, err := svc.RunIfDue(ctx)
	if err != nil {
		t.Fatal(err)
	}
	if res.Ran || dest.uploads != 2 {
		t.Fatalf("expected skip, got ran=%v uploads=%d", res.Ran, dest.uploads)
	}

	// An hourly check landing a moment before 24h still counts as due.
	clk.t = clk.t.Add(time.Hour - time.Second)
	if res, err = svc.RunIfDue(ctx); err != nil || !res.Ran {
		t.Fatalf("expected backup to run, ran=%v err=%v", res.Ran, err)
	}
}

func TestService_PrunesExpiredDumps(t *testing.T) {
	clk := &stepClock{t: time.Date(2026, 10, 1, 3, 0, 0, 0, time.UTC)}
	dest := newMemDestination(clk.Now)
	svc := newTestService(t, clk, dest)
	ctx := context.Background()

	for range 6 {
		if _, err := svc.RunIfDue(ctx); err != nil {
			t.Fatal(err)
		}
		clk.t = clk.t.Add(24 * time.Hour)
	}

	files, _ := dest.List(ctx)
	if n := len(dbDumps(files)); n != 4 { // 3-day window, inclusive of its edge
		t.Fatalf("kept %d dumps, want 4: %v", n, names(files))
	}
	assertMedia(t, dest, string(dest.byName(mediaLatestName)[0]), string(dest.byName(mediaPreviousName)[0]))
}

func TestService_DumpFailureUploadsNothing(t *testing.T) {
	clk := &stepClock{t: time.Date(2026, 10, 1, 3, 0, 0, 0, time.UTC)}
	dest := newMemDestination(clk.Now)
	svc := newTestService(t, clk, dest)
	svc.dump = func(context.Context, string, string) error { return errors.New("connection refused") }

	if _, err := svc.RunIfDue(context.Background()); err == nil {
		t.Fatal("expected error")
	}
	if dest.uploads != 0 {
		t.Fatalf("uploads = %d, want 0", dest.uploads)
	}
}
