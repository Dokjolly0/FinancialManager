package backup

import (
	"context"
	"os"
	"path/filepath"
	"testing"
	"time"
)

func writeTemp(t *testing.T, content string) string {
	t.Helper()
	p := filepath.Join(t.TempDir(), "media.tar.gz.enc")
	if err := os.WriteFile(p, []byte(content), 0o600); err != nil {
		t.Fatal(err)
	}
	return p
}

func assertMedia(t *testing.T, dest *memDestination, latest, previous string) {
	t.Helper()
	check := func(name, want string) {
		got := dest.byName(name)
		switch {
		case want == "" && len(got) != 0:
			t.Errorf("%s: expected none, got %d", name, len(got))
		case want != "" && (len(got) != 1 || string(got[0]) != want):
			t.Errorf("%s: got %q, want %q", name, got, want)
		}
	}
	check(mediaLatestName, latest)
	check(mediaPreviousName, previous)
	check(mediaUploadingName, "")
}

func TestRotateMedia(t *testing.T) {
	ctx := context.Background()
	dest := newMemDestination(time.Now)

	if _, err := rotateMedia(ctx, dest, writeTemp(t, "v1")); err != nil {
		t.Fatal(err)
	}
	assertMedia(t, dest, "v1", "")

	if _, err := rotateMedia(ctx, dest, writeTemp(t, "v2")); err != nil {
		t.Fatal(err)
	}
	assertMedia(t, dest, "v2", "v1")

	if _, err := rotateMedia(ctx, dest, writeTemp(t, "v3")); err != nil {
		t.Fatal(err)
	}
	assertMedia(t, dest, "v3", "v2")
}

func TestRotateMedia_FailedUploadKeepsExistingCopies(t *testing.T) {
	ctx := context.Background()
	dest := newMemDestination(time.Now)
	_, _ = rotateMedia(ctx, dest, writeTemp(t, "v1"))
	_, _ = rotateMedia(ctx, dest, writeTemp(t, "v2"))

	dest.failUpload = true
	if _, err := rotateMedia(ctx, dest, writeTemp(t, "v3")); err == nil {
		t.Fatal("expected upload error")
	}
	assertMedia(t, dest, "v2", "v1")
}

func TestRotateMedia_RemovesStaleUpload(t *testing.T) {
	ctx := context.Background()
	dest := newMemDestination(time.Now)
	_, _ = rotateMedia(ctx, dest, writeTemp(t, "v1"))
	dest.add(mediaUploadingName, []byte("truncated"))

	if _, err := rotateMedia(ctx, dest, writeTemp(t, "v2")); err != nil {
		t.Fatal(err)
	}
	assertMedia(t, dest, "v2", "v1")
}
