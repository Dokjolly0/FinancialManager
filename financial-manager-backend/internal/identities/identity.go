// Package identities implements external (federated) identities linked to
// an application account (plan.md section 4.1, 11.4). Google is the only
// provider today; the schema and repository are provider-agnostic so
// Apple/passkey can be added later without a rewrite.
package identities

import (
	"time"

	"github.com/google/uuid"
)

const ProviderGoogle = "google"

type ExternalIdentity struct {
	ID                    uuid.UUID
	UserID                uuid.UUID
	Provider              string
	ProviderSubject       string
	ProviderEmail         *string
	ProviderEmailVerified *bool
	LinkedAt              time.Time
	LastUsedAt            *time.Time
}
