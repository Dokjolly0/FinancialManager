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
	Transfers        []TransferFlow
	Recurring        []Recurring

	// Transactions is the optional raw list, newest first.
	Transactions        []Transaction
	TransactionsOmitted int

	// Context is the personal context; nil when not included.
	Context *Context
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
