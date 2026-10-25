package prompt

import "time"

// Snapshot is everything the data block can show, already aggregated and
// filtered by the ai package. Amounts are in minor units of Currency.
// Empty slices are rendered as "no data" lines; nil pointers are omitted.
type Snapshot struct {
	PeriodFrom *time.Time // nil: the whole history
	PeriodTo   time.Time  // exclusive
	Timezone   string
	Currency   string

	Wallets []Wallet
	Totals  Totals

	// Months, categories, titles, transfers and recurring are only
	// rendered when their section is selected (see Section*).
	Months           []Month
	DebitCategories  []Group
	CreditCategories []Group
	DebitTitles      []Group
	CreditTitles     []Group
	// CreditTitlesOmitted / TransfersOmitted: the section existed but was
	// dropped to fit a token budget (see Trim).
	CreditTitlesOmitted bool
	TransfersOmitted    bool
	Transfers           []TransferFlow
	Recurring           []Recurring
	// NonMonthly lists likely yearly and large one-off expenses; part of
	// the recurring section.
	NonMonthly []NonMonthly

	// Transactions is the optional raw list, newest first.
	Transactions        []Transaction
	TransactionsOmitted int

	// Context is the personal context; nil when not included.
	Context *Context

	// Filters, when set, restrict every figure to matching transactions
	// (an analysis started from Cronologia). Balances and transfers are
	// then left out: a partial view of the ledger can't compute them.
	Filters *Filters
}

// Filters describes the transactions an analysis is restricted to.
type Filters struct {
	Direction      string // DEBIT, CREDIT or ""
	Category       string // category name, "" for any
	Title          string // text searched in title and description
	AmountMinMinor int64  // 0: no bound
	AmountMaxMinor int64  // 0: no bound
}

type Wallet struct {
	Name         string
	Type         string // CASH, BANK, OTHER, MEAL_VOUCHER
	Purpose      string
	BalanceMinor int64
	Archived     bool
}

type Totals struct {
	CreditsMinor int64
	DebitsMinor  int64
	Count        int64
	OpeningMinor *int64 // nil for the whole history
	ClosingMinor int64
}

type Month struct {
	Month        string // YYYY-MM
	CreditsMinor int64
	DebitsMinor  int64
}

type Group struct {
	Label       string
	AmountMinor int64
	Count       int64
}

type TransferFlow struct {
	From        string
	To          string
	AmountMinor int64
	Count       int64
}

type Recurring struct {
	Label             string
	Months            int
	AvgAmountMinor    int64
	LastAmountMinor   int64
	LastSeenMonth     string // YYYY-MM
	AmountsVaryLittle bool   // within 10% of the average
}

// Signals of a non-monthly expense, strongest first.
const (
	SignalAnnualGap  = "annual_gap"  // the same item about 12 months apart
	SignalAnnualWord = "annual_word" // the title says it is yearly
	SignalOneOff     = "one_off"     // seen once, much larger than usual
)

type NonMonthly struct {
	Label           string
	Months          int // distinct months it was seen in
	LastAmountMinor int64
	LastSeenMonth   string // YYYY-MM
	Signal          string
	// MonthlyEquivalentMinor is the last amount spread over 12 months for
	// yearly items, 0 for one-off ones.
	MonthlyEquivalentMinor int64
}

type Transaction struct {
	Date        string // YYYY-MM-DD in the user's timezone
	Wallet      string
	Credit      bool
	AmountMinor int64
	Title       string
	Category    string
}

type Context struct {
	HouseholdSize *int
	IncomeType    *string
	AboutMe       *string
	Goals         *string
	IgnoreNotes   *string
}
