package backup

import (
	"archive/tar"
	"compress/gzip"
	"context"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"time"

	"financial-manager-backend/internal/platform/storage"
)

// objectSource is the slice of the object store the media archive needs.
// storage.MinIOStore satisfies it; List is deliberately not part of
// storage.Store (see its doc comment).
type objectSource interface {
	List(ctx context.Context, fn func(storage.ObjectInfo) error) error
	Get(ctx context.Context, key string) (io.ReadCloser, error)
}

var _ objectSource = (*storage.MinIOStore)(nil)

// ArchiveStats summarizes an archived bucket for the job's log line.
type ArchiveStats struct {
	Objects int
	Bytes   int64
}

// ArchiveMedia writes every object in src to path as a tar.gz whose entry
// names are the object keys — the same layout `mc mirror` produces in
// scripts/backup.sh, so restoring is "extract, then mc mirror back".
func ArchiveMedia(ctx context.Context, src objectSource, path string) (ArchiveStats, error) {
	f, err := os.Create(path)
	if err != nil {
		return ArchiveStats{}, err
	}
	gz := gzip.NewWriter(f)
	tw := tar.NewWriter(gz)

	var stats ArchiveStats
	now := time.Now()
	walkErr := src.List(ctx, func(obj storage.ObjectInfo) error {
		if err := tw.WriteHeader(&tar.Header{
			Name:    obj.Key,
			Mode:    0o644,
			Size:    obj.SizeBytes,
			ModTime: now,
		}); err != nil {
			return err
		}
		body, err := src.Get(ctx, obj.Key)
		if err != nil {
			return fmt.Errorf("get %s: %w", obj.Key, err)
		}
		n, err := io.Copy(tw, body)
		_ = body.Close()
		if err != nil {
			return fmt.Errorf("copy %s: %w", obj.Key, err)
		}
		stats.Objects++
		stats.Bytes += n
		return nil
	})

	// Close every layer even on failure so the file handle is released;
	// the first error wins.
	errs := []error{walkErr, tw.Close(), gz.Close(), f.Close()}
	for _, err := range errs {
		if err != nil {
			return ArchiveStats{}, fmt.Errorf("archive media: %w", err)
		}
	}
	return stats, nil
}

// ExtractMedia unpacks an archive written by ArchiveMedia into dir, one file
// per object key, so it can be inspected or mirrored back into a bucket
// (`mc mirror dir dst/bucket`). Entries whose name would land outside dir
// ("../x", absolute paths) are rejected rather than skipped: a well-formed
// backup never contains them.
func ExtractMedia(archivePath, dir string) (ArchiveStats, error) {
	f, err := os.Open(archivePath)
	if err != nil {
		return ArchiveStats{}, err
	}
	defer f.Close()
	gz, err := gzip.NewReader(f)
	if err != nil {
		return ArchiveStats{}, fmt.Errorf("extract media: %w", err)
	}
	tr := tar.NewReader(gz)

	var stats ArchiveStats
	for {
		h, err := tr.Next()
		if err == io.EOF {
			return stats, nil
		}
		if err != nil {
			return stats, fmt.Errorf("extract media: %w", err)
		}
		if h.Typeflag != tar.TypeReg {
			continue
		}
		if !filepath.IsLocal(h.Name) {
			return stats, fmt.Errorf("extract media: unsafe entry name %q", h.Name)
		}
		dst := filepath.Join(dir, filepath.FromSlash(h.Name))
		if err := os.MkdirAll(filepath.Dir(dst), 0o755); err != nil {
			return stats, err
		}
		out, err := os.Create(dst)
		if err != nil {
			return stats, err
		}
		n, err := io.Copy(out, tr)
		if closeErr := out.Close(); err == nil {
			err = closeErr
		}
		if err != nil {
			return stats, fmt.Errorf("extract %s: %w", h.Name, err)
		}
		stats.Objects++
		stats.Bytes += n
	}
}
