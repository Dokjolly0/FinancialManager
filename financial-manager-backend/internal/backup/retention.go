package backup

import (
	"sort"
	"strings"
	"time"
)

// Database dumps are kept as a dated history (unlike media, see
// rotation.go): they're small, and a history is what protects against a
// data problem noticed days or weeks later.
const (
	dbDumpPrefix     = "fm-"
	dbDumpSuffix     = "-postgres.dump" + encryptedExt
	dbDumpTimeLayout = "20060102T150405Z"
)

func dbDumpName(at time.Time) string {
	return dbDumpPrefix + at.UTC().Format(dbDumpTimeLayout) + dbDumpSuffix
}

// parseDBDumpTime extracts the timestamp from a dump's file name. The name,
// not Drive's createdTime, is the source of truth: it is what we wrote, and
// it survives a manual re-upload.
func parseDBDumpTime(name string) (time.Time, bool) {
	if !strings.HasPrefix(name, dbDumpPrefix) || !strings.HasSuffix(name, dbDumpSuffix) {
		return time.Time{}, false
	}
	ts, err := time.Parse(dbDumpTimeLayout, strings.TrimSuffix(strings.TrimPrefix(name, dbDumpPrefix), dbDumpSuffix))
	if err != nil {
		return time.Time{}, false
	}
	return ts, true
}

type datedDump struct {
	file RemoteFile
	at   time.Time
}

// dbDumps returns the database dumps among files, newest first.
func dbDumps(files []RemoteFile) []datedDump {
	var out []datedDump
	for _, f := range files {
		if at, ok := parseDBDumpTime(f.Name); ok {
			out = append(out, datedDump{file: f, at: at})
		}
	}
	sort.Slice(out, func(i, j int) bool { return out[i].at.After(out[j].at) })
	return out
}

// selectExpired returns the database dumps that fall outside the retention
// policy:
//   - every dump from the last `days` days is kept;
//   - the first dump of each of the last `months` calendar months (the
//     current one included) is kept as a monthly snapshot;
//   - the newest dump is always kept, so a worker that was down for longer
//     than the retention window never prunes its way to zero backups.
//
// Files that aren't database dumps (media archives, foreign files) are
// never selected.
func selectExpired(files []RemoteFile, now time.Time, days, months int) []RemoteFile {
	dumps := dbDumps(files)
	if len(dumps) == 0 {
		return nil
	}

	now = now.UTC()
	dailyCutoff := now.Add(-time.Duration(days) * 24 * time.Hour)
	monthStart := func(t time.Time) time.Time { return time.Date(t.Year(), t.Month(), 1, 0, 0, 0, 0, time.UTC) }
	oldestMonth := monthStart(now).AddDate(0, -(months - 1), 0)

	// Walk oldest first, so the first dump seen in a month is that month's
	// snapshot.
	monthly := map[time.Time]bool{}
	keep := map[string]bool{dumps[0].file.ID: true}
	for i := len(dumps) - 1; i >= 0; i-- {
		d := dumps[i]
		if !d.at.Before(dailyCutoff) {
			keep[d.file.ID] = true
		}
		m := monthStart(d.at)
		if months > 0 && !m.Before(oldestMonth) && !monthly[m] {
			monthly[m] = true
			keep[d.file.ID] = true
		}
	}

	var expired []RemoteFile
	for _, d := range dumps {
		if !keep[d.file.ID] {
			expired = append(expired, d.file)
		}
	}
	return expired
}
