package backup

import (
	"context"
	"time"
)

// RemoteFile is a backup artifact stored at the destination.
type RemoteFile struct {
	ID          string
	Name        string
	CreatedTime time.Time
	SizeBytes   int64
}

// Destination is where encrypted backups are uploaded. DriveDestination is
// the production implementation; tests use an in-memory fake.
type Destination interface {
	// List returns every backup artifact at the destination.
	List(ctx context.Context) ([]RemoteFile, error)
	// Upload stores the local file at localPath under name.
	Upload(ctx context.Context, name, localPath string) (RemoteFile, error)
	// Rename changes a stored file's name without re-uploading it.
	Rename(ctx context.Context, id, newName string) error
	// Delete permanently removes a stored file.
	Delete(ctx context.Context, id string) error
}
