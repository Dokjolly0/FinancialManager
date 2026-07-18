package storage

import (
	"context"
	"errors"
	"io"
	"time"

	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"
)

// MinIOStore implements Store against a MinIO (or any S3-compatible) endpoint.
type MinIOStore struct {
	client *minio.Client
	bucket string
}

// MinIOConfig configures a MinIOStore.
type MinIOConfig struct {
	Endpoint  string
	AccessKey string
	SecretKey string
	Bucket    string
	UseSSL    bool
}

// NewMinIOStore connects to the configured endpoint and ensures the target
// bucket exists, creating it if necessary. Bucket creation is idempotent so
// this is safe to call on every startup.
func NewMinIOStore(ctx context.Context, cfg MinIOConfig) (*MinIOStore, error) {
	client, err := minio.New(cfg.Endpoint, &minio.Options{
		Creds:  credentials.NewStaticV4(cfg.AccessKey, cfg.SecretKey, ""),
		Secure: cfg.UseSSL,
	})
	if err != nil {
		return nil, err
	}

	exists, err := client.BucketExists(ctx, cfg.Bucket)
	if err != nil {
		return nil, err
	}
	if !exists {
		if err := client.MakeBucket(ctx, cfg.Bucket, minio.MakeBucketOptions{}); err != nil {
			return nil, err
		}
	}

	return &MinIOStore{client: client, bucket: cfg.Bucket}, nil
}

func (s *MinIOStore) Put(ctx context.Context, key string, content io.Reader, size int64, contentType string) (ObjectInfo, error) {
	info, err := s.client.PutObject(ctx, s.bucket, key, content, size, minio.PutObjectOptions{
		ContentType: contentType,
	})
	if err != nil {
		return ObjectInfo{}, err
	}
	return ObjectInfo{Key: key, SizeBytes: info.Size, ContentType: contentType}, nil
}

func (s *MinIOStore) Get(ctx context.Context, key string) (io.ReadCloser, error) {
	obj, err := s.client.GetObject(ctx, s.bucket, key, minio.GetObjectOptions{})
	if err != nil {
		return nil, err
	}
	if _, err := obj.Stat(); err != nil {
		_ = obj.Close()
		return nil, err
	}
	return obj, nil
}

func (s *MinIOStore) Delete(ctx context.Context, key string) error {
	err := s.client.RemoveObject(ctx, s.bucket, key, minio.RemoveObjectOptions{})
	if err != nil {
		var errResp minio.ErrorResponse
		if errors.As(err, &errResp) && errResp.Code == "NoSuchKey" {
			return nil
		}
		return err
	}
	return nil
}

func (s *MinIOStore) PresignedGetURL(ctx context.Context, key string, expiry time.Duration) (string, error) {
	u, err := s.client.PresignedGetObject(ctx, s.bucket, key, expiry, nil)
	if err != nil {
		return "", err
	}
	return u.String(), nil
}
