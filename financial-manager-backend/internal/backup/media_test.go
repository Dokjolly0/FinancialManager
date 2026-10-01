package backup

import (
	"archive/tar"
	"bytes"
	"compress/gzip"
	"context"
	"errors"
	"io"
	"os"
	"path/filepath"
	"sort"
	"testing"

	"financial-manager-backend/internal/platform/storage"
)

type fakeObjects map[string][]byte

func (f fakeObjects) List(_ context.Context, fn func(storage.ObjectInfo) error) error {
	keys := make([]string, 0, len(f))
	for k := range f {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	for _, k := range keys {
		if err := fn(storage.ObjectInfo{Key: k, SizeBytes: int64(len(f[k]))}); err != nil {
			return err
		}
	}
	return nil
}

func (f fakeObjects) Get(_ context.Context, key string) (io.ReadCloser, error) {
	b, ok := f[key]
	if !ok {
		return nil, errors.New("not found")
	}
	return io.NopCloser(bytes.NewReader(b)), nil
}

func TestArchiveMedia(t *testing.T) {
	src := fakeObjects{
		"users/a/1.jpg": []byte("first image"),
		"users/b/2.png": bytes.Repeat([]byte{7}, 5000),
	}
	path := filepath.Join(t.TempDir(), "media.tar.gz")

	stats, err := ArchiveMedia(context.Background(), src, path)
	if err != nil {
		t.Fatal(err)
	}
	if stats.Objects != 2 || stats.Bytes != int64(len("first image")+5000) {
		t.Fatalf("stats = %+v", stats)
	}

	f, err := os.Open(path)
	if err != nil {
		t.Fatal(err)
	}
	defer f.Close()
	gz, err := gzip.NewReader(f)
	if err != nil {
		t.Fatal(err)
	}
	tr := tar.NewReader(gz)
	got := map[string][]byte{}
	for {
		h, err := tr.Next()
		if err == io.EOF {
			break
		}
		if err != nil {
			t.Fatal(err)
		}
		b, _ := io.ReadAll(tr)
		got[h.Name] = b
	}
	for k, want := range src {
		if !bytes.Equal(got[k], want) {
			t.Errorf("entry %s mismatch", k)
		}
	}
}

func TestArchiveMedia_EmptyBucket(t *testing.T) {
	path := filepath.Join(t.TempDir(), "media.tar.gz")
	stats, err := ArchiveMedia(context.Background(), fakeObjects{}, path)
	if err != nil || stats.Objects != 0 {
		t.Fatalf("stats=%+v err=%v", stats, err)
	}
}
