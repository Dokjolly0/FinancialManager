package wallets

import (
	"strings"
	"testing"

	"financial-manager-backend/internal/platform/apierror"
)

func TestNormalizePurpose(t *testing.T) {
	ptr := func(s string) *string { return &s }

	tests := []struct {
		name      string
		in        *string
		want      *string
		wantError bool
	}{
		{name: "nil stays nil", in: nil, want: nil},
		{name: "empty becomes nil", in: ptr(""), want: nil},
		{name: "blank becomes nil", in: ptr("  \n\t "), want: nil},
		{name: "trimmed", in: ptr("  fondo emergenze "), want: ptr("fondo emergenze")},
		{name: "max length in runes", in: ptr(strings.Repeat("è", MaxPurposeLength)), want: ptr(strings.Repeat("è", MaxPurposeLength))},
		{name: "too long", in: ptr(strings.Repeat("a", MaxPurposeLength+1)), wantError: true},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got, fieldErrors := NormalizePurpose(tt.in)
			if tt.wantError {
				if fieldErrors["purpose"] != apierror.FieldPurposeLength {
					t.Fatalf("fieldErrors = %v, want purpose=%s", fieldErrors, apierror.FieldPurposeLength)
				}
				return
			}
			if len(fieldErrors) > 0 {
				t.Fatalf("unexpected fieldErrors = %v", fieldErrors)
			}
			if (got == nil) != (tt.want == nil) || (got != nil && *got != *tt.want) {
				t.Fatalf("NormalizePurpose() = %v, want %v", deref(got), deref(tt.want))
			}
		})
	}
}

func deref(s *string) string {
	if s == nil {
		return "<nil>"
	}
	return *s
}
