package prompt

// labels holds the data block's localized words. Only Italian and English
// exist; any other locale falls back to English (see LangFor).
type labels struct {
	periodHeading, periodFrom, periodWholeHistory, periodNote string

	walletsHeading, walletColumns, archived, noPurpose string
	walletTypes                                        map[string]string

	totalsHeading, totalsColumns, balancesColumns, savingsRateNA string

	monthsHeading, monthsColumns string

	debitCategoriesHeading, creditCategoriesHeading, groupColumnsCategory string
	debitTitlesHeading, creditTitlesHeading, groupColumnsTitle            string

	transfersHeading, transfersColumns, transfersNote string

	recurringHeading, recurringColumns, recurringNote, yes, no string

	transactionsHeading, transactionsColumns, transactionsOmitted string
	credit, debit, uncategorized                                  string

	noData string

	filtersHeading, filtersNote, filterDebit, filterCredit, filterCategory, filterTitle string
	filterAmountFrom, filterAmountTo, filteredBalances, filteredTransfers               string

	contextHousehold, contextIncome, contextAboutMe, contextGoals, contextIgnore string
	incomeTypes                                                                  map[string]string
}

var italian = labels{
	periodHeading:      "## Periodo",
	periodFrom:         "Dal %s al %s",
	periodWholeHistory: "Tutta la cronologia fino al %s",
	periodNote:         "Fuso orario %s. Importi in %s, con il punto come separatore decimale.",

	walletsHeading: "## Portafogli",
	walletColumns:  "nome | tipo | scopo | saldo attuale",
	archived:       " (archiviato)",
	noPurpose:      "-",
	walletTypes: map[string]string{
		"CASH": "contanti", "BANK": "conto bancario", "OTHER": "altro", "MEAL_VOUCHER": "buoni pasto",
	},

	totalsHeading:   "## Totali del periodo (trasferimenti esclusi)",
	totalsColumns:   "entrate | uscite | risultato netto | movimenti | tasso di risparmio",
	balancesColumns: "saldo a inizio periodo | saldo a fine periodo",
	savingsRateNA:   "n.d.",

	monthsHeading: "## Andamento mensile",
	monthsColumns: "mese | entrate | uscite | netto",

	debitCategoriesHeading:  "## Uscite per categoria",
	creditCategoriesHeading: "## Entrate per categoria",
	groupColumnsCategory:    "categoria | importo | quota | movimenti",
	debitTitlesHeading:      "## Principali voci di spesa",
	creditTitlesHeading:     "## Principali voci di entrata",
	groupColumnsTitle:       "voce | importo | quota | movimenti",

	transfersHeading: "## Trasferimenti tra portafogli",
	transfersColumns: "da | a | importo | movimenti",
	transfersNote:    "Spostano denaro tra portafogli dell'utente: non sono né entrate né uscite.",

	recurringHeading: "## Possibili spese ricorrenti",
	recurringColumns: "voce | mesi in cui compare | importo medio | ultimo importo | ultimo mese | importo stabile",
	recurringNote:    "Individuate automaticamente: stessa voce in almeno 3 mesi diversi. Possono includere falsi positivi.",
	yes:              "sì",
	no:               "no",

	transactionsHeading: "## Movimenti (dal più recente)",
	transactionsColumns: "data | portafoglio | tipo | importo | voce | categoria",
	transactionsOmitted: "Altri %d movimenti meno recenti non sono inclusi.",
	credit:              "entrata",
	debit:               "uscita",
	uncategorized:       "-",

	noData: "Nessun dato.",

	filtersHeading:    "## Filtri applicati",
	filtersNote:       "Tutti i dati qui sotto riguardano solo i movimenti che rispettano questi filtri.",
	filterDebit:       "Solo uscite",
	filterCredit:      "Solo entrate",
	filterCategory:    "Categoria: %s",
	filterTitle:       "Titolo o descrizione contiene: %q",
	filterAmountFrom:  "Importo minimo: %s",
	filterAmountTo:    "Importo massimo: %s",
	filteredBalances:  "Saldi non disponibili: l'analisi riguarda solo una parte dei movimenti.",
	filteredTransfers: "Non inclusi: con i filtri attivi l'analisi riguarda solo entrate e uscite.",

	contextHousehold: "Persone nel nucleo familiare: %d",
	contextIncome:    "Tipo di reddito: %s",
	contextAboutMe:   "Su di me: %s",
	contextGoals:     "Obiettivi: %s",
	contextIgnore:    "Da non considerare o da interpretare così: %s",
	incomeTypes: map[string]string{
		"EMPLOYEE": "lavoro dipendente", "SELF_EMPLOYED": "lavoro autonomo", "STUDENT": "studente",
		"RETIRED": "pensione", "UNEMPLOYED": "senza reddito da lavoro", "MIXED": "misto", "OTHER": "altro",
	},
}

var english = labels{
	periodHeading:      "## Period",
	periodFrom:         "From %s to %s",
	periodWholeHistory: "Whole history up to %s",
	periodNote:         "Timezone %s. Amounts in %s, with a dot as the decimal separator.",

	walletsHeading: "## Wallets",
	walletColumns:  "name | type | purpose | current balance",
	archived:       " (archived)",
	noPurpose:      "-",
	walletTypes: map[string]string{
		"CASH": "cash", "BANK": "bank account", "OTHER": "other", "MEAL_VOUCHER": "meal vouchers",
	},

	totalsHeading:   "## Period totals (transfers excluded)",
	totalsColumns:   "income | expenses | net result | transactions | savings rate",
	balancesColumns: "balance at period start | balance at period end",
	savingsRateNA:   "n/a",

	monthsHeading: "## Monthly trend",
	monthsColumns: "month | income | expenses | net",

	debitCategoriesHeading:  "## Expenses by category",
	creditCategoriesHeading: "## Income by category",
	groupColumnsCategory:    "category | amount | share | transactions",
	debitTitlesHeading:      "## Top expense items",
	creditTitlesHeading:     "## Top income items",
	groupColumnsTitle:       "item | amount | share | transactions",

	transfersHeading: "## Transfers between wallets",
	transfersColumns: "from | to | amount | transactions",
	transfersNote:    "They move money between the user's own wallets: neither income nor expenses.",

	recurringHeading: "## Possible recurring expenses",
	recurringColumns: "item | months seen | average amount | last amount | last month | stable amount",
	recurringNote:    "Detected automatically: the same item in at least 3 different months. May include false positives.",
	yes:              "yes",
	no:               "no",

	transactionsHeading: "## Transactions (newest first)",
	transactionsColumns: "date | wallet | type | amount | item | category",
	transactionsOmitted: "%d older transactions are not included.",
	credit:              "income",
	debit:               "expense",
	uncategorized:       "-",

	noData: "No data.",

	filtersHeading:    "## Applied filters",
	filtersNote:       "Every figure below only covers the transactions matching these filters.",
	filterDebit:       "Expenses only",
	filterCredit:      "Income only",
	filterCategory:    "Category: %s",
	filterTitle:       "Title or description contains: %q",
	filterAmountFrom:  "Minimum amount: %s",
	filterAmountTo:    "Maximum amount: %s",
	filteredBalances:  "Balances not available: the analysis only covers part of the transactions.",
	filteredTransfers: "Not included: with filters on, the analysis only covers income and expenses.",

	contextHousehold: "People in the household: %d",
	contextIncome:    "Income type: %s",
	contextAboutMe:   "About me: %s",
	contextGoals:     "Goals: %s",
	contextIgnore:    "Ignore or interpret this way: %s",
	incomeTypes: map[string]string{
		"EMPLOYEE": "employee", "SELF_EMPLOYED": "self-employed", "STUDENT": "student",
		"RETIRED": "retired", "UNEMPLOYED": "no work income", "MIXED": "mixed", "OTHER": "other",
	},
}

func labelsFor(lang Lang) labels {
	if lang == LangIT {
		return italian
	}
	return english
}
