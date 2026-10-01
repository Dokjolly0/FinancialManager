package backup

import (
	"context"
	"errors"
	"fmt"
	"os"
	"sort"
	"time"
)

// memDestination is an in-memory Destination. failUpload makes the next
// Upload fail without storing anything.
type memDestination struct {
	files      map[string]RemoteFile
	content    map[string][]byte
	nextID     int
	now        func() time.Time
	failUpload bool
	uploads    int
}

func newMemDestination(now func() time.Time) *memDestination {
	return &memDestination{files: map[string]RemoteFile{}, content: map[string][]byte{}, now: now}
}

func (m *memDestination) add(name string, content []byte) RemoteFile {
	m.nextID++
	f := RemoteFile{ID: fmt.Sprintf("id-%03d", m.nextID), Name: name, CreatedTime: m.now(), SizeBytes: int64(len(content))}
	m.files[f.ID] = f
	m.content[f.ID] = content
	return f
}

func (m *memDestination) List(context.Context) ([]RemoteFile, error) {
	out := make([]RemoteFile, 0, len(m.files))
	for _, f := range m.files {
		out = append(out, f)
	}
	sort.Slice(out, func(i, j int) bool { return out[i].ID < out[j].ID })
	return out, nil
}

func (m *memDestination) Upload(_ context.Context, name, localPath string) (RemoteFile, error) {
	if m.failUpload {
		m.failUpload = false
		return RemoteFile{}, errors.New("simulated upload failure")
	}
	b, err := os.ReadFile(localPath)
	if err != nil {
		return RemoteFile{}, err
	}
	m.uploads++
	return m.add(name, b), nil
}

func (m *memDestination) Rename(_ context.Context, id, newName string) error {
	f, ok := m.files[id]
	if !ok {
		return errors.New("not found")
	}
	f.Name = newName
	m.files[id] = f
	return nil
}

func (m *memDestination) Delete(_ context.Context, id string) error {
	delete(m.files, id)
	delete(m.content, id)
	return nil
}

// byName returns the contents of every file with the given name.
func (m *memDestination) byName(name string) [][]byte {
	var out [][]byte
	files, _ := m.List(context.Background())
	for _, f := range files {
		if f.Name == name {
			out = append(out, m.content[f.ID])
		}
	}
	return out
}
