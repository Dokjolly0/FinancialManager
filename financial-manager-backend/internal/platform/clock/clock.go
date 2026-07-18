// Package clock provides an injectable time source so business logic that
// depends on "now" (occurred_at defaults, token expiry, reconciliation) can
// be tested deterministically instead of calling time.Now directly.
package clock

import "time"

// Clock returns the current instant in UTC.
type Clock interface {
	Now() time.Time
}

// System is the production Clock backed by the operating system clock.
type System struct{}

// Now returns the current UTC time.
func (System) Now() time.Time {
	return time.Now().UTC()
}

// Frozen is a Clock that always returns a fixed instant. Useful in tests.
type Frozen struct {
	At time.Time
}

// Now returns the frozen instant.
func (f Frozen) Now() time.Time {
	return f.At
}
