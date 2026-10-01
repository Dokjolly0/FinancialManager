package backup

import (
	"slices"
	"sort"
	"testing"
	"time"
)

func dumpsAt(times ...time.Time) []RemoteFile {
	files := make([]RemoteFile, len(times))
	for i, at := range times {
		name := dbDumpName(at)
		files[i] = RemoteFile{ID: name, Name: name}
	}
	return files
}

func names(files []RemoteFile) []string {
	out := make([]string, 0, len(files))
	for _, f := range files {
		out = append(out, f.Name)
	}
	sort.Strings(out)
	return out
}

func TestDBDumpNameRoundTrip(t *testing.T) {
	at := time.Date(2026, 10, 1, 3, 4, 5, 0, time.UTC)
	got, ok := parseDBDumpTime(dbDumpName(at))
	if !ok || !got.Equal(at) {
		t.Fatalf("parse(%s) = %v, %v", dbDumpName(at), got, ok)
	}
	for _, name := range []string{mediaLatestName, "fm-garbage-postgres.dump.enc", "notes.txt"} {
		if _, ok := parseDBDumpTime(name); ok {
			t.Errorf("%q parsed as a dump", name)
		}
	}
}

func TestSelectExpired_DailyAndMonthly(t *testing.T) {
	now := time.Date(2026, 10, 15, 3, 0, 0, 0, time.UTC)
	day := func(m time.Month, d int) time.Time { return time.Date(2026, m, d, 3, 0, 0, 0, time.UTC) }

	files := dumpsAt(
		day(10, 14), day(10, 10), // within the 7-day window
		day(10, 2), day(10, 1), // October: the 1st is the monthly snapshot
		day(9, 20), day(9, 3), // September: the 3rd is the snapshot
		day(8, 31), // August: outside the 2-month window
	)
	files = append(files, RemoteFile{ID: "media", Name: mediaLatestName})

	got := names(selectExpired(files, now, 7, 2))
	want := names(dumpsAt(day(10, 2), day(9, 20), day(8, 31)))
	if !slices.Equal(got, want) {
		t.Fatalf("expired = %v, want %v", got, want)
	}
}

func TestSelectExpired_AlwaysKeepsNewest(t *testing.T) {
	now := time.Date(2026, 10, 15, 0, 0, 0, 0, time.UTC)
	old := time.Date(2025, 1, 1, 0, 0, 0, 0, time.UTC)
	files := dumpsAt(old, old.Add(-24*time.Hour))

	got := names(selectExpired(files, now, 30, 0))
	want := names(dumpsAt(old.Add(-24 * time.Hour)))
	if !slices.Equal(got, want) {
		t.Fatalf("expired = %v, want %v (the newest dump must survive)", got, want)
	}
}
