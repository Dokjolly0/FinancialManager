package backup

import (
	"context"
	"fmt"
	"os"
	"strings"
	"sync"
	"time"

	"golang.org/x/oauth2"
	"golang.org/x/oauth2/google"
	"google.golang.org/api/drive/v3"
	"google.golang.org/api/googleapi"
	"google.golang.org/api/option"
)

// DriveScope is the only OAuth scope the backup job asks for. drive.file
// lets the app see and manage just the files it created itself — never the
// rest of the user's Drive — and, being a non-sensitive scope, needs no
// Google app verification. cmd/gdrive-auth requests the same scope.
const DriveScope = drive.DriveFileScope

const folderMimeType = "application/vnd.google-apps.folder"

// uploadChunkSize makes uploads resumable in 8 MiB chunks, so a transient
// network error doesn't restart a large media archive from scratch.
const uploadChunkSize = 8 * 1024 * 1024

// DriveConfig configures a DriveDestination.
type DriveConfig struct {
	ClientID     string
	ClientSecret string
	RefreshToken string
	FolderName   string
}

// DriveDestination stores backups in a single Google Drive folder, which it
// creates on first use. Because of the drive.file scope the folder can't be
// created by hand: a folder the app didn't create is invisible to it.
type DriveDestination struct {
	svc        *drive.Service
	folderName string

	mu       sync.Mutex
	folderID string // resolved lazily, then cached
}

var _ Destination = (*DriveDestination)(nil)

// NewDriveDestination builds a Drive client that refreshes its access token
// from cfg.RefreshToken. ctx must outlive the destination: token refreshes
// use it.
func NewDriveDestination(ctx context.Context, cfg DriveConfig) (*DriveDestination, error) {
	oauthCfg := &oauth2.Config{
		ClientID:     cfg.ClientID,
		ClientSecret: cfg.ClientSecret,
		Endpoint:     google.Endpoint,
		Scopes:       []string{DriveScope},
	}
	ts := oauthCfg.TokenSource(ctx, &oauth2.Token{RefreshToken: cfg.RefreshToken})
	svc, err := drive.NewService(ctx, option.WithTokenSource(ts))
	if err != nil {
		return nil, fmt.Errorf("create drive client: %w", err)
	}
	return &DriveDestination{svc: svc, folderName: cfg.FolderName}, nil
}

// quoteQuery escapes a value for a Drive search query string literal.
func quoteQuery(s string) string {
	s = strings.ReplaceAll(s, `\`, `\`)
	return "'" + strings.ReplaceAll(s, "'", `\'`) + "'"
}

func (d *DriveDestination) folder(ctx context.Context) (string, error) {
	d.mu.Lock()
	defer d.mu.Unlock()
	if d.folderID != "" {
		return d.folderID, nil
	}

	q := fmt.Sprintf("name = %s and mimeType = %s and trashed = false",
		quoteQuery(d.folderName), quoteQuery(folderMimeType))
	res, err := d.svc.Files.List().Q(q).Spaces("drive").Fields("files(id)").PageSize(1).Context(ctx).Do()
	if err != nil {
		return "", fmt.Errorf("find backup folder: %w", err)
	}
	if len(res.Files) > 0 {
		d.folderID = res.Files[0].Id
		return d.folderID, nil
	}

	created, err := d.svc.Files.Create(&drive.File{Name: d.folderName, MimeType: folderMimeType}).
		Fields("id").Context(ctx).Do()
	if err != nil {
		return "", fmt.Errorf("create backup folder: %w", err)
	}
	d.folderID = created.Id
	return d.folderID, nil
}

func toRemoteFile(f *drive.File) RemoteFile {
	created, _ := time.Parse(time.RFC3339, f.CreatedTime)
	return RemoteFile{ID: f.Id, Name: f.Name, CreatedTime: created, SizeBytes: f.Size}
}

const fileFields = "id, name, createdTime, size"

func (d *DriveDestination) List(ctx context.Context) ([]RemoteFile, error) {
	folderID, err := d.folder(ctx)
	if err != nil {
		return nil, err
	}
	q := fmt.Sprintf("%s in parents and trashed = false", quoteQuery(folderID))
	var out []RemoteFile
	err = d.svc.Files.List().Q(q).Spaces("drive").PageSize(1000).
		Fields(googleapi.Field("nextPageToken, files("+fileFields+")")).
		Pages(ctx, func(page *drive.FileList) error {
			for _, f := range page.Files {
				out = append(out, toRemoteFile(f))
			}
			return nil
		})
	if err != nil {
		return nil, fmt.Errorf("list backups: %w", err)
	}
	return out, nil
}

func (d *DriveDestination) Upload(ctx context.Context, name, localPath string) (RemoteFile, error) {
	folderID, err := d.folder(ctx)
	if err != nil {
		return RemoteFile{}, err
	}
	f, err := os.Open(localPath)
	if err != nil {
		return RemoteFile{}, err
	}
	defer f.Close()

	created, err := d.svc.Files.Create(&drive.File{Name: name, Parents: []string{folderID}}).
		Media(f, googleapi.ChunkSize(uploadChunkSize), googleapi.ContentType("application/octet-stream")).
		Fields(fileFields).Context(ctx).Do()
	if err != nil {
		return RemoteFile{}, fmt.Errorf("upload %s: %w", name, err)
	}
	return toRemoteFile(created), nil
}

func (d *DriveDestination) Rename(ctx context.Context, id, newName string) error {
	if _, err := d.svc.Files.Update(id, &drive.File{Name: newName}).Fields("id").Context(ctx).Do(); err != nil {
		return fmt.Errorf("rename %s to %s: %w", id, newName, err)
	}
	return nil
}

// Delete removes the file permanently rather than moving it to the trash:
// trashed files still count against the account's 15 GB quota.
func (d *DriveDestination) Delete(ctx context.Context, id string) error {
	if err := d.svc.Files.Delete(id).Context(ctx).Do(); err != nil {
		return fmt.Errorf("delete %s: %w", id, err)
	}
	return nil
}
