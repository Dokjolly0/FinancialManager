package backup

import (
	"context"
	"fmt"
)

// The media archive can be large and old copies have little value, so
// instead of a dated history it is rotated between two fixed names.
const (
	mediaLatestName    = "fm-media-latest.tar.gz" + encryptedExt
	mediaPreviousName  = "fm-media-previous.tar.gz" + encryptedExt
	mediaUploadingName = "fm-media.tar.gz" + encryptedExt + ".uploading"
)

// rotateMedia uploads localPath as the new "latest" media archive and
// demotes the current one to "previous". The order guarantees at least one
// complete archive exists at every step, whatever fails:
//
//  1. upload under a temporary name — nothing existing is touched until
//     the new archive is safely stored;
//  2. delete the old "previous";
//  3. rename "latest" → "previous";
//  4. rename the temporary file → "latest".
//
// A temporary file left behind by an earlier failed run is deleted first:
// it may be incomplete, and "latest" or "previous" still holds a good copy.
func rotateMedia(ctx context.Context, dest Destination, localPath string) (RemoteFile, error) {
	files, err := dest.List(ctx)
	if err != nil {
		return RemoteFile{}, err
	}
	var latest, previous []RemoteFile
	for _, f := range files {
		switch f.Name {
		case mediaUploadingName:
			if err := dest.Delete(ctx, f.ID); err != nil {
				return RemoteFile{}, fmt.Errorf("delete stale upload: %w", err)
			}
		case mediaLatestName:
			latest = append(latest, f)
		case mediaPreviousName:
			previous = append(previous, f)
		}
	}

	uploaded, err := dest.Upload(ctx, mediaUploadingName, localPath)
	if err != nil {
		return RemoteFile{}, err
	}
	for _, f := range previous {
		if err := dest.Delete(ctx, f.ID); err != nil {
			return RemoteFile{}, fmt.Errorf("delete previous media archive: %w", err)
		}
	}
	for _, f := range latest {
		if err := dest.Rename(ctx, f.ID, mediaPreviousName); err != nil {
			return RemoteFile{}, fmt.Errorf("demote latest media archive: %w", err)
		}
	}
	if err := dest.Rename(ctx, uploaded.ID, mediaLatestName); err != nil {
		return RemoteFile{}, fmt.Errorf("promote new media archive: %w", err)
	}
	uploaded.Name = mediaLatestName
	return uploaded, nil
}
