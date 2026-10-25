# Complete implementation plan — Personal finance management app

**Version:** 1.0  
**Date:** July 18, 2026  
**Planned stack:** Flutter · Go · PostgreSQL · Redis · Docker  
**Required host ports:** PostgreSQL `10001` · Redis `10002` · API `10003` · MinIO `10004`

---

## Table of contents

1. [Product goal](#1-product-goal)
2. [Critical review of the initial draft](#2-critical-review-of-the-initial-draft)
3. [MVP scope and later features](#3-mvp-scope-and-later-features)
4. [Terminology and domain rules](#4-terminology-and-domain-rules)
5. [Information architecture and navigation](#5-information-architecture-and-navigation)
6. [Design system and UI guidelines](#6-design-system-and-ui-guidelines)
7. [Detailed screen specifications](#7-detailed-screen-specifications)
8. [Main user flows](#8-main-user-flows)
9. [Flutter architecture](#9-flutter-architecture)
10. [Go backend architecture](#10-go-backend-architecture)
11. [PostgreSQL data model](#11-postgresql-data-model)
12. [Redis's role](#12-rediss-role)
13. [Reliable balance management](#13-reliable-balance-management)
14. [REST API contract](#14-rest-api-contract)
15. [Authentication and Google linking](#15-authentication-and-google-linking)
16. [Image management, search, and crop](#16-image-management-search-and-crop)
17. [History, search, and filters](#17-history-search-and-filters)
18. [Reports, percentages, and charts](#18-reports-percentages-and-charts)
19. [Security](#19-security)
20. [Privacy and data management](#20-privacy-and-data-management)
21. [Docker and environments](#21-docker-and-environments)
22. [Observability, logging, and monitoring](#22-observability-logging-and-monitoring)
23. [Test strategy](#23-test-strategy)
24. [CI/CD and release](#24-cicd-and-release)
25. [Implementation roadmap](#25-implementation-roadmap)
26. [Acceptance criteria](#26-acceptance-criteria)
27. [Risks and mitigations](#27-risks-and-mitigations)
28. [Decisions to confirm before development](#28-decisions-to-confirm-before-development)
29. [Recommended repository structure](#29-recommended-repository-structure)
30. [Definition of Done](#30-definition-of-done)
31. [Technical references](#31-technical-references)
32. [AI analysis (Analisi AI)](#32-ai-analysis-analisi-ai)

---

## 1. Product goal

The app must let a person manage their balance in a way that is simple yet verifiable, record income and expenses, quickly find past operations, and understand their financial trend over time.

The product must have four core qualities:

1. **Speed:** entering a common transaction must take only a few seconds.
2. **Reliability:** every change that affects the balance must be traceable.
3. **Readability:** balance, income, expenses, and trend must be understandable without accounting knowledge.
4. **Extensibility:** the MVP must be able to evolve toward multiple accounts, automatic recurrences, budgets, exports, and bank synchronization without rewriting the core.

### 1.1 Initial target users

- A person who wants to replace notes or spreadsheets with a mobile solution.
- A person who manually records expenses and income.
- A person who wants to compare months and understand which titles or categories weigh the most.
- A person who does not need, in the first version, automatic bank connection.

### 1.2 Product principles

- The displayed balance must always be traceable to recorded transactions.
- Destructive actions must be reversible or clearly confirmed.
- PostgreSQL is the authoritative source of financial data.
- Redis must not hold the only copy of any financial data.
- Amounts must never be handled with floating-point numbers.
- Dates must be stored in UTC and displayed in the user's time zone.
- The interface must distinguish income and expenses without relying solely on color.

---

## 2. Critical review of the initial draft

The draft already contains the correct core of the product. To make it implementable, however, some corrections and additions are needed.

### 2.1 Necessary changes

#### A. Manually changing the balance becomes a "balance adjustment"

A number in the profile must not be directly overwritten, because the explanation for the difference would be lost. When the user sets a different balance, the system must create a special transaction:

- technical type: `BALANCE_ADJUSTMENT`;
- amount: difference between the current balance and the desired balance;
- default title: "Balance adjustment";
- optional but recommended description;
- excluded by default from ordinary income/expense charts;
- always visible in history, with a dedicated indicator.

Example: recorded balance €500, actual balance €470. The app creates a `-€30` adjustment.

#### B. Adding the concept of category

The title alone is not enough for consistent reports. "Bar Centrale," "Caffè Roma," and "Colazione" might represent the same economic category but have different titles.

A category is therefore added, with a default value of "Other." In reports, the user will be able to group:

- by **title/template** — original requirement;
- by **category** — a more useful view for analysis;
- in the future, by merchant, tag, or account.

#### C. Adding email to manual registration

Email is needed for:

- password recovery;
- security alerts;
- identity verification;
- possible linking to Google;
- account export or deletion.

Updated registration fields:

- first name;
- last name;
- username;
- email;
- password;
- confirm password;
- profile picture or generated avatar;
- initial balance;
- currency;
- acceptance of the documents required by the product.

#### D. Separating "reusing a title" from "automatic recurrence"

The described requirement is mainly about autocompleting already-used transactions. In the MVP, **reusable templates** will be created: selecting a previous title pre-fills category, image, and usual data.

Automatic monthly or weekly transaction creation is kept as a later phase, because it requires notifications, error handling, time zones, and confirmation of scheduled operations.

#### E. Adding storage for images

PostgreSQL and Redis are not suited to directly hold all image files. The plan calls for:

- PostgreSQL for metadata and references;
- S3-compatible storage, preferably MinIO in a self-hosted environment, or a cloud bucket in production;
- the backend as the sole authorized point for upload, validation, and initial distribution.

MinIO can stay on the internal Docker network without a public host port. Alternatively, for a very small MVP, a persistent volume managed by the backend can be used, keeping the same abstract interface.

#### F. Adding edit and delete operations

A useful history must allow correcting mistakes. For every transaction the following are planned:

- detail view;
- edit;
- logical deletion;
- atomic balance update;
- audit of the action.

#### G. Adding currency and time zone

Even with a single initial currency, every wallet must have an ISO code, e.g. `EUR`. The profile also stores locale and time zone, e.g. `it-IT` and `Europe/Rome`.

#### H. Adding export and account deletion

These are important features for an app that stores personal financial data:

- CSV/JSON export;
- account deletion request;
- deletion or anonymization according to the defined policy;
- session revocation and external-provider unlinking.

### 2.2 Features not needed in the MVP

These are deferred to avoid increasing the risk of the first release:

- automatic bank synchronization;
- shared management among multiple users;
- multiple wallets or accounts per user;
- currency conversion;
- advanced budgets;
- AI-based forecasts;
- automatic receipt recognition;
- automatic recurrences;
- bulk import from statements.

The architecture must nonetheless avoid choices that would make these features impossible later.

---

## 3. MVP scope and later features

> **Status note (2026-08):** several §3.2 post-MVP items are already delivered and superseded by later sections — multiple accounts/wallets and transfers between them (§11.6, §14.4), and a `MEAL_VOUCHER` wallet type with voucher lots, expiry tracking, and split expenses (§4.1, §11.6, §11.14/§11.15, §14.4/14.5) that wasn't on this list at all when it was written. This note is left inline rather than rewriting the roadmap below, which still reflects the original MVP-era planning.

### 3.1 Mandatory MVP

- Full manual registration.
- Manual login.
- Google sign-in linked to a complete application account.
- Non-negative initial balance.
- Single wallet in EUR, but schema ready for other currencies.
- Home with balance and latest transactions.
- Income/expense entry.
- Reusable templates and suggestions from already-used titles.
- Transaction category.
- Image from an already-used library.
- Image search via a configured provider.
- Image upload and crop.
- Paginated history.
- Filters by title, amount, date range, type, and category.
- Detail, edit, and delete of a transaction.
- Balance adjustment.
- Reports for the last 30 days, last 12 months, entire history, and custom period.
- Breakdown by title and category.
- Monthly comparison when the period spans at least two months.
- Profile and avatar editing.
- Google linking and unlinking.
- Logout from the device and logout from all devices.
- Data export.
- Account deletion.
- Light and dark theme.
- Italian localization; structure ready for other languages.

### 3.2 Recommended next phase

- Automatic recurrences or reminders for recurring transactions.
- Monthly budgets per category.
- Multiple accounts/wallets.
- Transfers between accounts.
- CSV import.
- Multiple attachments and receipts.
- Push notifications.
- Reports exportable to PDF.
- Home screen widget.
- Passkey login.
- Full offline synchronization.

---

## 4. Terminology and domain rules

### 4.1 Main entities

- **User:** application identity, independent of the authentication method.
- **Local credential:** password associated with the user.
- **External identity:** Google link identified by the verified `sub` of the Google token.
- **Wallet:** container for the balance and transactions. In the MVP there is one per user.
- **Transaction:** a movement that changes the balance.
- **Transaction template:** reusable data for frequent transactions.
- **Category:** economic classification, e.g. "Home," "Transport," "Salary."
- **Media asset:** an uploaded, searched, or reused image.
- **Adjustment:** a special transaction used to align the balance.
- **Voucher lot:** a batch of meal vouchers loaded onto a `MEAL_VOUCHER` wallet in one operation, all sharing one expiry date computed from the wallet's expiry policy; consumed FIFO by that date (§11.14/§11.15, §14.4).

### 4.2 Transaction types

Economic direction:

- `CREDIT`: increases the balance;
- `DEBIT`: decreases the balance.

Technical nature:

- `STANDARD`: a normal income or expense;
- `OPENING_BALANCE`: initial balance;
- `BALANCE_ADJUSTMENT`: manual adjustment;
- `TRANSFER`: a wallet-to-wallet move, two linked rows via `transfer_pair_id`, excluded from expense/income report totals;
- in the future `IMPORT`, `RECURRING_GENERATED`.

A meal-voucher expense that isn't fully covered by vouchers produces two `STANDARD` rows linked via `linked_transaction_id` instead — the voucher-wallet leg and an other-wallet leg for the shortfall. Unlike `transfer_pair_id`, both legs stay `STANDARD` (not a new kind) so they count normally in expense reports.

### 4.3 Rules for amounts

- The amount entered by the user is always greater than zero.
- The direction determines the sign applied to the balance.
- In the database the amount is stored in minor units, e.g. cents, as a `BIGINT` integer.
- Example: `€12.34` is stored as `1234`.
- The initial balance must be `>= 0`.
- After registration, the balance may become negative as a result of debits, unless a product decision states otherwise.
- The backend validates reasonable maximum limits to prevent overflow or anomalous input.
- For a `MEAL_VOUCHER` wallet, every amount affecting its balance is quantized: always `N × voucher_unit_value_minor` for a whole number of vouchers `N`, never an arbitrary amount (§11.14).

### 4.4 Rules for title and template

- Title is required, recommended length 1–120 characters.
- The original text is kept for display.
- A normalized title is also computed: trimmed, whitespace collapsed, and compared case-insensitively.
- If a transaction comes from a template, the template reference is preferred for grouping.
- Suggestions are ordered by frequency and recent use.
- If the user edits a field after selecting a template, the transaction can diverge without automatically updating the template.
- After saving, an "Also update the template" action can be offered.

### 4.5 Time rules

- `occurred_at`: the actual date and time of the operation, editable.
- `created_at`: when the record was created.
- `updated_at`: last modification.
- All persisted dates are `timestamptz` in UTC.
- The client displays them in the profile's time zone.
- Date filters must have clear, inclusive semantics.
- Custom periods are converted to UTC ranges by the backend using the user's time zone.

---

## 5. Information architecture and navigation

### 5.1 Primary navigation

Bottom bar with four destinations and a center button:

1. **Home**
2. **History**
3. **Add** — prominent center button
4. **Reports**
5. **Account**

The "Add" button opens the entry screen directly. A long press or a bottom sheet can offer two shortcuts:

- New expense;
- New income.

The web dashboard (section 9.9) keeps the same destinations (plus "Analisi AI") and the same "Aggiungi" rules: below 768 px a bottom bar with the center button, as on phones; from 768 px a collapsible sidebar and a top bar with a "+ Aggiungi" menu (income/expense, transfer with two or more wallets, meal-voucher credit/expense when a voucher wallet exists) and the user menu. `Ctrl+K` opens a command palette for pages and quick actions.

### 5.2 Section hierarchy

```text
Authentication
├── Splash / session restore
├── Login
├── Registration
├── Google registration completion
├── Password recovery
└── Email verification

Authenticated area
├── Home
│   ├── Balance
│   ├── Period summary
│   └── Recent transactions
├── New transaction
│   ├── Type selection
│   ├── Transaction data
│   ├── Image selection
│   └── Crop / preview
├── History
│   ├── Search
│   ├── Filters
│   └── Detail / edit
├── Reports
│   ├── Period
│   ├── Summary
│   ├── Breakdown
│   └── Monthly comparison
└── Account
    ├── Profile
    ├── Avatar
    ├── Balance and adjustment
    ├── Security
    ├── Linked accounts
    ├── Preferences
    ├── Data export
    └── Deletion / logout
```

---

## 6. Design system and UI guidelines

### 6.1 Visual direction

Recommended style: **financial, calm, trustworthy, not traditional-bank-like**.

Characteristics:

- clean surfaces;
- highly legible numbers;
- clear typographic hierarchy;
- moderate use of cards;
- simple icons;
- brief, functional animations;
- charts understandable even on small screens.

### 6.2 Material Design

Use Material 3 as a base, customizing tokens and components. Avoid building from scratch behaviors already solved by the framework, such as date pickers, bottom sheets, snack bars, and navigation bars.

The web dashboard does not use Material: its components are built on Tailwind CSS 4 (design tokens as CSS variables in `src/styles.css`, light and dark) and the Angular CDK for the behaviors (dialogs, drawers and bottom sheets, menus, overlays, focus trapping). It keeps the palette, the semantic credit/debit colors, the typography scale and the generated avatars of this section, so the two clients look related. Font: Inter, self-hosted.

### 6.3 Proposed palette

#### Light theme

- Primary: `#176B5B`
- Primary container: `#D7F4EC`
- Background: `#F7F9F8`
- Surface: `#FFFFFF`
- Text primary: `#16201D`
- Text secondary: `#5C6965`
- Border: `#DCE4E1`
- Credit semantic: `#067647`
- Debit semantic: `#B42318`
- Warning: `#B54708`
- Info: `#175CD3`

#### Dark theme

- Background: `#0E1513`
- Surface: `#17211E`
- Elevated surface: `#1F2B27`
- Text primary: `#F1F6F4`
- Text secondary: `#AAB8B3`
- Primary: `#65CDB5`

Income and expenses must also differ via icon, `+/-` sign, label, and position — not just via green and red.

### 6.4 Typography

- Balance display: 36–44 sp, weight 700.
- Page title: 24–28 sp, weight 650–700.
- Card title: 16–18 sp, weight 600.
- Body: 14–16 sp.
- Secondary data: 12–14 sp.
- Amounts in lists: tabular figures, right-aligned.

### 6.5 Spacing and shapes

- Base grid: 4 px.
- Page padding: 16 px mobile, 24 px tablet.
- Main spacing steps: 8, 12, 16, 24, 32 px.
- Card radius: 16–20 px.
- Input radius: 12–16 px.
- Minimum touch target: 48×48 px.

### 6.6 Reusable components

- `BalanceCard`
- `TransactionTile`
- `AmountField`
- `DirectionSegmentedControl`
- `PeriodSelector`
- `FilterChipGroup`
- `CategoryPicker`
- `MediaPickerTile`
- `EmptyState`
- `InlineError`
- `SkeletonList`
- `StatCard`
- `BreakdownChartCard`
- `MonthlyComparisonCard`
- `GeneratedAvatar`
- `ConfirmationSheet`

### 6.7 Accessibility

- Support text scaling without clipping amounts or buttons.
- Semantic labels for charts and icons.
- Contrast verified for light and dark theme.
- Do not use color as the only indicator.
- Allow keyboard navigation on tablet and web: the web dashboard is fully keyboard-operable (focus trapped in dialogs and restored on close, visible focus rings, `Ctrl+K` palette).
- Reduce or disable animations when requested by the system.
- Provide a textual or tabular summary for every chart.

---

## 7. Detailed screen specifications

## 7.1 Splash and session restore

### Goal

Quickly determine whether to show login, onboarding, or the authenticated area.

### Content

- Logo/app mark.
- Discreet loading indicator.
- No financial data shown until the session is validated.

### Behavior

1. Securely read the refresh token and local state.
2. Attempt a session refresh.
3. Load profile and wallet.
4. If the profile is incomplete, open registration completion.
5. If there is no network, show local data in a limited mode only if a previously valid session exists.

## 7.2 Login

### Fields

- Username or email.
- Password.
- Show/hide password.
- "Forgot password?".
- "Sign in" button.
- "or" separator.
- Official "Continue with Google" button.
- "Create an account" link.

### States

- Inline validation.
- Loading state on the button.
- Wrong credentials with a not-overly-specific message.
- Unverified account with an action to resend the email.
- Rate limit with a message and retry time.

## 7.3 Manual registration

To avoid an overly long page, use a three-step flow.

### Step 1 — Account

- First name.
- Last name.
- Username.
- Email.
- Password.
- Confirm password.

Validations:

- unique, normalized username;
- valid, unique email;
- password compliant with policy;
- matching confirmation.

### Step 2 — Profile

- Generated avatar preview.
- Custom image choice.
- Avatar background color.
- Avatar text color.
- Optional initial theme.

The generated avatar is not saved as a file. Only mode and colors are saved in the database.

### Step 3 — Wallet

- Initial balance.
- Currency, default EUR.
- Detected time zone, editable.
- Data summary.
- Registration confirmation.

The initial balance creates an `OPENING_BALANCE` transaction and initializes the current balance in the same database transaction.

## 7.4 Registration with Google

Google is a method of proving identity, not a replacement for the application profile.

Flow:

1. Google authentication on the device.
2. Sending the ID token to the backend.
3. Server-side token verification.
4. If the identity is already linked, immediate login.
5. If not linked, creation of a temporary registration ticket.
6. Opening registration with first name, last name, and email pre-filled when available.
7. Requesting username, optional local password, avatar, initial balance, currency, and consents.
8. Account creation and atomic linking of the Google identity.

The local password can be optional only if the product accepts exclusively federated accounts. To reduce the risk of lockout after unlinking, the recommended plan requires setting a password before being able to unlink the only external provider.

## 7.5 Home

### Proposed layout

```text
┌──────────────────────────────────────┐
│ Hi, Mario                       [●]  │
│                                      │
│  Available balance                   │
│  € 2,430.50                  [eye]   │
│  updated just now                    │
│                                      │
│  [+ Income]       [- Expense]        │
├──────────────────────────────────────┤
│ This month                           │
│ Income €2,100   Expenses €1,240      │
│ Net +€860                            │
├──────────────────────────────────────┤
│ Latest transactions        See all   │
│ ● Salary                  +€2,000    │
│ ● Bar Centrale               -€4.50  │
│ ● Fuel                       -€60.00 │
└──────────────────────────────────────┘
```

### Components

- Greeting and avatar.
- Balance card with the option to hide the value.
- Quick income/expense actions.
- Mini summary of the current month.
- Latest 5–10 transactions.
- Optional non-intrusive banner to complete email verification or backup.

### Interactions

- Tap balance: wallet detail and adjustment.
- Tap transaction: detail.
- Optional swipe on the transaction: edit/delete, only after UX validation.
- Pull-to-refresh.

## 7.6 New transaction

### Structure

1. "Expense / Income" segment.
2. Prominent amount field.
3. Title with autocomplete.
4. Category.
5. Date and time.
6. Image/icon.
7. Optional description.
8. Optional "Save/Update template" toggle.
9. "Save transaction" button.

### Title behavior

- Show suggestions after 1–2 characters.
- Each suggestion shows title, category, image, and last use.
- Selecting a suggestion pre-fills the associated values.
- Suggestions are filtered by direction: expense templates for expenses, income templates for income.
- The user can still change every field.

### Amount

- Numeric keypad.
- Locale formatting while typing.
- No manual negative sign.
- Direction change via a dedicated control.
- Visual confirmation: `+ €` or `- €`.

### Saving

- The button stays disabled until amount and title are valid.
- The client generates a unique `Idempotency-Key`.
- Prevent double taps while saving.
- After success, show feedback and return to the previous screen.
- "Add another" option in the success message.

## 7.7 Image picker

Bottom sheet or page with four tabs:

1. **Recent** — recently used images.
2. **Library** — all images saved by the user.
3. **Search** — results from the configured provider.
4. **Upload** — camera or gallery.

Every image must show selection state, possible source, and a preview action.

## 7.8 Image crop

### Profile

- 1:1 crop.
- Circular mask in preview, but square resulting file.
- Zoom and pan.
- Optional rotation.
- Recommended output: 512×512.

### Transaction

- 1:1 crop.
- Preview in the actual transaction component.
- Recommended output: 256×256 or 512×512.

### Rules

- If the image is already compatible, still offer a preview but don't force changes.
- If it's larger or has an incompatible ratio, open the crop.
- The backend must still re-decode and re-encode the file, without trusting the client's result.

## 7.9 History

### Header

- "History" title.
- Text search bar.
- Filter button with a badge showing the number of active filters.
- Sorting, default "Most recent."

### List

- Grouped by day.
- Optional net total for the day.
- Infinite scroll or cursor-based pagination.
- Each row shows image, title, category, time, and amount.
- Adjustments and initial balance have a dedicated style.

### Filters

- Text title.
- Minimum amount.
- Maximum amount.
- Start date.
- End date.
- Type: all, expenses, income, adjustments.
- Category.
- With/without image, optional.
- Sort by date or amount.

### Filter UX

- Full-height bottom sheet.
- "Clear" and "Apply" actions.
- Summary chips above the list.
- Filters persist while the screen stays open.
- Specific empty state: "No transactions match the filters."

## 7.10 Transaction detail

Contents:

- image;
- title;
- amount and direction;
- category;
- actual date and time;
- description;
- creation date and last edit, in a secondary section;
- origin: manual, adjustment, initial balance;
- edit and delete actions.

Deletion:

- confirmation bottom sheet;
- indication of the resulting balance;
- soft delete;
- possibility of immediate undo, when technically possible.

## 7.11 Edit transaction

Reuses the entry form. The backend computes the difference between the old and new impact on the balance within the same database transaction.

Concurrency:

- the record includes a `version`;
- the client sends the version it read;
- on conflict it receives `409 Conflict` and is prompted to reload the data.

## 7.12 Reports

### Period header

Presets:

- Last 30 days.
- Last 12 months.
- Entire history.
- Custom.

Optionally add "Current month" and "Current year," with unambiguous names.

### Summary section

- Starting balance for the period.
- Total ordinary income.
- Total ordinary expenses.
- Net result.
- Ending balance.
- Number of transactions.
- Savings rate, only when income is positive.

### Trend chart

- Cumulative balance line, or income/expense bars per day or month.
- Automatic granularity:
  - up to 45 days: daily;
  - 46–400 days: monthly;
  - beyond: monthly or yearly.

### Breakdown

Two tabs:

- By title/template.
- By category.

For expenses, show a donut or sorted bars with percentages. For income, use a separate view, avoiding mixing the two denominators.

### Monthly comparison

Show only if the range includes at least two distinct months.

- side-by-side income/expense bars;
- a net line or indicator;
- tap a month to see the detail;
- accessible table below the chart.

## 7.13 Account

Sections:

### Profile

- First name.
- Last name.
- Username.
- Email and verification status.
- Avatar.

### Wallet

- Current balance.
- Currency.
- Balance adjustment.
- Future account management.

### Security

- Change password.
- Active sessions.
- Logout from all devices.
- Possible future passkey.

### Linked accounts

- Google linked/not linked.
- Link.
- Unlink.
- Last used date.

### Preferences

- System/light/dark theme.
- Time zone.
- Language.
- Balance visibility on open.
- First day of the week.

### Data

- Export CSV.
- Export JSON.
- Delete account.

### Session

- Logout.

## 7.14 Generated avatar

The client generates the avatar using:

- first name initial;
- last name initial;
- saved background color;
- saved text color.

If the first or last name changes, the initials change automatically. No file is saved as long as the user keeps the generated mode.

## 7.15 Cross-cutting states

Every screen must have:

- initial loading;
- non-blocking refresh;
- recoverable error;
- unrecoverable error;
- empty state;
- no network;
- expired session;
- camera/gallery permission denied.

---

## 8. Main user flows

### 8.1 First manual registration

```mermaid
flowchart TD
    A[Open app] --> B[Registration]
    B --> C[Account data]
    C --> D[Profile and avatar]
    D --> E[Initial balance and currency]
    E --> F[Create user and wallet]
    F --> G[Create initial balance transaction]
    G --> H[Home]
```

### 8.2 Google registration or login

```mermaid
flowchart TD
    A[Continue with Google] --> B[Google returns ID token]
    B --> C[Backend verifies token]
    C --> D{Identity already linked?}
    D -- Yes --> E[Create session]
    E --> F[Home]
    D -- No --> G[Temporary registration ticket]
    G --> H[Complete required data]
    H --> I[Create account + link Google]
    I --> F
```

### 8.3 Entering a recurring transaction

```mermaid
flowchart TD
    A[Add expense] --> B[Enter amount]
    B --> C[Type title]
    C --> D[Select suggestion]
    D --> E[Pre-fill category and image]
    E --> F[Confirm date and description]
    F --> G[Save with idempotency key]
    G --> H[Atomic DB transaction]
    H --> I[Balance updated]
```

### 8.4 Balance adjustment

```mermaid
flowchart TD
    A[Account > Balance adjustment] --> B[Show current balance]
    B --> C[Enter actual balance]
    C --> D[Compute difference]
    D --> E[Confirm effect]
    E --> F[Create BALANCE_ADJUSTMENT]
    F --> G[Update balance atomically]
```

---

## 9. Flutter architecture

### 9.1 Approach

Adopt a **feature-first** structure with separation between UI, domain, and data. The model can be described as MVVM with repositories and services.

Principles:

- immutable UI state;
- unidirectional data flow;
- views with no business logic;
- repository as the data source for the feature;
- use cases for operations that combine multiple repositories or rules;
- injected dependencies;
- API models separated from domain models.

### 9.2 Recommended Flutter stack

Versions must be pinned in the lockfile and updated through a controlled process.

- State management and dependency injection: `flutter_riverpod` or an alternative approved via ADR.
- Declarative routing: `go_router`.
- HTTP: `dio` or a client generated from OpenAPI.
- Serialization: `json_serializable` and immutable models.
- Secure token storage: a wrapper over Keychain/Keystore, e.g. `flutter_secure_storage`.
- Local database/cache: `drift` over SQLite, if a persistent cache is implemented.
- Images: `image_picker` plus a crop library evaluated with a spike.
- Charts: a library with touch and accessibility support, e.g. `fl_chart`.
- Localization: `flutter_localizations` and ARB files.
- Logging/crash reporting: a provider-independent abstraction.

### 9.3 Client folder structure

```text
lib/
├── app/
│   ├── app.dart
│   ├── bootstrap.dart
│   ├── router.dart
│   ├── theme/
│   └── localization/
├── core/
│   ├── api/
│   ├── auth/
│   ├── errors/
│   ├── formatting/
│   ├── storage/
│   ├── widgets/
│   └── observability/
├── features/
│   ├── authentication/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   ├── home/
│   ├── transactions/
│   ├── history/
│   ├── reports/
│   ├── media/
│   └── account/
└── main.dart
```

Each feature:

```text
feature/
├── data/
│   ├── dto/
│   ├── services/
│   └── repositories/
├── domain/
│   ├── models/
│   ├── repositories/
│   └── use_cases/
└── presentation/
    ├── screens/
    ├── view_models/
    ├── state/
    └── widgets/
```

### 9.4 State management

Separate:

- server/cache state: profile, wallet, transactions, reports;
- ephemeral state: form values, selected tab, crop;
- minimal global state: session, theme, locale.

Do not keep the balance as client-modifiable global state. After a mutation, use the authoritative backend response and invalidate the related queries.

### 9.5 Networking

The client must include:

- base URL per environment (`lib/core/api/api_environment.dart`: production `https://financialmanager.alexviolatto.dev/api/v1`, local `http://10.0.2.2:10003/v1` for the Android emulator; `--dart-define=API_BASE_URL` overrides both);
- differentiated timeouts;
- access-token interceptor;
- serialized refresh token, avoiding concurrent refresh requests;
- correlation/request ID;
- mapping API errors → domain errors;
- retry only for idempotent requests or ones protected by an idempotency key;
- request cancellation when a screen is closed.

### 9.6 Cache and offline mode

Recommended MVP:

- encrypted or protected local cache for home and recent history;
- offline reading of already-synced data;
- transaction creation/editing only online;
- clear indicator for potentially stale data.

Later phase:

- local mutation queue;
- client-generated UUIDs;
- idempotency key;
- conflict strategy;
- background synchronization.

### 9.7 Amount formatting

Create a `Money` domain type:

```text
Money {
  minorUnits: int64
  currency: String
}
```

The client must not send `12.34` as a floating-point value. The API contract can use:

```json
{
  "amount_minor": 1234,
  "currency": "EUR"
}
```

### 9.8 Routing and guards

Main routes:

```text
/splash
/login
/register
/register/google-completion
/forgot-password
/reset-password?token=…      -- link in the reset email, any session state
/verify-email?token=…        -- link in the verification email, any session state
/app/home
/app/transactions/new
/app/transactions/:id
/app/transactions/:id/edit
/app/history
/app/reports
/app/account
/app/account/profile
/app/account/security
/app/account/linked-accounts
/app/account/data
```

Guards:

- not authenticated → login;
- authenticated but incomplete profile → completion;
- authenticated and complete → app area;
- refresh failed → controlled local logout.

While the session is being restored the splash keeps the requested location (`/splash?from=/app/history`) and opens it afterwards, so an App Link lands where it pointed. The two email-link routes are open in every session state and also come back through the splash.

The email links are `https://financialmanager.alexviolatto.dev/...` URLs: on Android they open the app through App Links (`autoVerify` intent-filter, `/.well-known/assetlinks.json` served by the web image with the signing key's SHA-256), elsewhere the web dashboard. iOS Universal Links are not set up.

The web dashboard (section 9.9) uses the same paths, so links and bookmarks work in both clients. It restores the session before the first navigation (no splash page; `/splash` redirects to `/app/home`), and adds two URLs for pages the app pushes without one: `/app/account/wallets/:id/denominations` and `/app/account/wallets/:id/voucher-lots`. A finished streamed analysis (`/app/ai/run`) replaces its URL with `/app/ai/analyses/:id`.

### 9.9 Web dashboard

The browser dashboard at `https://financialmanager.alexviolatto.dev` is a separate client, `financial-manager-web/`: **Angular 22** (standalone components, zoneless change detection, signals, `OnPush`), **Tailwind CSS 4** and the **Angular CDK**. It has the app's features except the on-device AI (section 33). Until October 2026 the dashboard was the Flutter app built for the browser; CanvasKit rendering, a `NavigationRail` layout and no access to modern web styling made it feel like a phone app in a window, so it was rewritten and the Flutter web build removed.

- **API**: same origin, `/api/v1` relative (production needs no CORS). In development `ng serve` runs on port 5000 and proxies `/api` to the API on `:10003` (`proxy.conf.json`), so development needs no CORS either and the default dev `APP_PUBLIC_URL` (`http://localhost:5000`) opens the local dashboard. Interceptors add `X-Request-ID` and the bearer token; creates send an `Idempotency-Key` (section 7.6) as the app does. Reads use `resource`/`httpResource`; AI streams use `fetch` with a `ReadableStream` SSE parser (POST with the bearer token, which `EventSource` can't send).
- **Session**: access token in memory, refresh token in `localStorage` (`fm.refresh_token`). Refresh is single-flight and runs inside a Web Lock (`navigator.locks`, `fm.refresh`) that re-reads the stored token first, so two tabs never present the same rotated token (the backend treats a replay as theft and revokes every session, section 15.6); a `storage` event signs the other tabs out together. A network error during refresh keeps the session; an invalid refresh token signs out. The CSP (section 19.3) limits which scripts could read the token.
- **Structure**: `core/` (API, auth, errors, formatting, i18n, session and guards, theme, media), `shared/ui/` (the UI kit), `layout/` (shell, "Aggiungi" menu, command palette), `features/<feature>/` with one lazy chunk per page. Business rules are ported from the app, not re-invented: money in integer minor units with `Intl.NumberFormat` (section 9.7), error codes → ARB keys, day grouping, report periods, "Aggiungi" rules, AI setup and preview models.
- **Routes**: the app's paths (section 9.8) with functional guards (`authGuard`, `guestGuard`, `googleCompletionGuard`, `aiGuard`; a `CanDeactivate` guard asks before leaving a running stream). Local-AI routes redirect to the AI settings. History and Reports keep their filters in the URL query.
- **Layout**: below 768 px a bottom bar with the center "Aggiungi" button, forms as full pages and quick actions as bottom sheets; from 768 px a collapsible sidebar (labels from 1024 px), a top bar with "+ Aggiungi", quick actions in a side drawer and content centered. Skeletons, empty states, inline errors and toasts as in section 7.15. Theme from `profile.theme` (system/light/dark) through a `dark` class on `<html>`.
- **i18n**: the app's ARB files are the source (`scripts/arb-to-json.mjs` merges them with a few web-only strings into `public/i18n/{it,en}.json` and fails on a missing key or placeholder); Transloco at runtime, following `profile.locale`. ICU messages are formatted by our own transpiler (`core/i18n/icu-transpiler.ts`) because `@messageformat/core` compiles with `new Function`, which the CSP forbids.
- **Google**: Google Identity Services' rendered button (section 15.2), the script loaded only where the button is shown.
- **Images and files**: `/media/{id}` needs the bearer token, so images are fetched as blobs and shown through object URLs (cached, revoked when unused). Uploads by file picker, drag and drop or the phone's camera (`capture`); cropping and rotation with `ngx-image-cropper`. Exports and AI reports download through a Blob.
- **Charts**: ECharts 6 (tree-shaken: line, bar, pie) through `ngx-echarts`, each with a table view (section 6.7); credit/debit colors chosen to stay distinguishable with color-vision deficiencies in both themes.
- **AI**: cloud providers only (section 32); markdown answers rendered with `marked` through Angular's sanitizer.
- **Tests**: Vitest unit and component tests; Playwright smoke tests on the production build with the API mocked and the production CSP enforced (section 23.10).
- **Deploy**: `financial-manager-web/Dockerfile` (Node build, then Caddy on `:8080`: hashed assets `immutable`, everything else `no-cache`, SPA fallback, `assetlinks.json`), built from the repository root because of the ARB files. CI (`web-ci.yml`, section 24.1) publishes it to Docker Hub as `dokjolly/financial-manager-web` (`latest` and `sha-<commit>`); service `web` in `compose.prod.yaml` pulls it (`pull_policy: always`, `WEB_IMAGE_TAG` for a rollback) and the host's Caddy proxies it. The VPS never builds the dashboard: on 1 vCPU / 2 GB a parallel Flutter + Go build exhausted memory (October 2026). Details in `docs/build-deploy.md` and `financial-manager-web/README.md`.

---

## 10. Go backend architecture

### 10.1 Architectural style

Use a **modular monolith**. It is simpler to deploy and test than microservices, while still keeping separate modules.

Modules:

- auth;
- users;
- wallets;
- transactions;
- templates;
- categories;
- media;
- reports;
- exports;
- audit.

### 10.2 Layers

```text
HTTP Handler
    ↓
Application Service / Use Case
    ↓
Domain Rules
    ↓
Repository Interfaces
    ↓
PostgreSQL / Redis / Object Storage / External providers
```

### 10.3 Backend structure

```text
cmd/
├── api/main.go
├── worker/main.go
└── migrate/main.go
internal/
├── platform/
│   ├── config/
│   ├── database/
│   ├── redis/
│   ├── httpserver/
│   ├── auth/
│   ├── storage/
│   ├── observability/
│   └── clock/
├── auth/
├── users/
├── wallets/
├── transactions/
├── templates/
├── categories/
├── media/
├── reports/
├── exports/
└── audit/
migrations/
openapi/
tests/
Dockerfile
compose.yaml
```

### 10.4 Recommended libraries

- HTTP: `net/http` with a lightweight router, e.g. `chi`, or an approved framework.
- PostgreSQL: `pgx` with a connection pool.
- Redis: `go-redis`.
- Migrations: `goose`, `golang-migrate`, or equivalent.
- Validation: a library with explicit rules plus domain validations.
- Password: `golang.org/x/crypto/argon2` with a versioned format.
- Logging: structured `log/slog`.
- Telemetry: OpenTelemetry.
- UUID: UUID v7 when available and validated, otherwise UUID v4.

### 10.5 Configuration

Configuration from environment variables, validated at startup:

```text
APP_ENV
HTTP_ADDR
DATABASE_URL
REDIS_ADDR
REDIS_PASSWORD
OBJECT_STORAGE_ENDPOINT
OBJECT_STORAGE_BUCKET
OBJECT_STORAGE_ACCESS_KEY
OBJECT_STORAGE_SECRET_KEY
GOOGLE_CLIENT_IDS
JWT_SIGNING_KEY / SESSION_SECRET
ACCESS_TOKEN_TTL
REFRESH_TOKEN_TTL
IMAGE_SEARCH_PROVIDER
IMAGE_SEARCH_API_KEY
MAX_UPLOAD_BYTES
ALLOWED_IMAGE_TYPES
```

No secrets in the repository or in Docker images.

### 10.6 Error model

Uniform format:

```json
{
  "error": {
    "code": "TRANSACTION_VERSION_CONFLICT",
    "message": "The transaction was modified by another session.",
    "field_errors": {
      "amount_minor": "Must be greater than zero"
    },
    "request_id": "..."
  }
}
```

The message can be localized client-side via `code`; the backend can provide a fallback.

### 10.7 Idempotency

Critical mutating endpoints, especially transaction creation and adjustments, must accept:

```http
Idempotency-Key: <uuid>
```

The key is unique per user and endpoint. The response of the first execution is reused for duplicate requests within the defined window.

### 10.8 Async jobs

The worker is useful for:

- generating image variants;
- large exports;
- deferred account deletion;
- cleaning up unused assets;
- sending email;
- future recurrence generation.

For the MVP the worker can be a second command in the same repository and the same Docker image.

---

## 11. PostgreSQL data model

### 11.1 Principles

- PostgreSQL is the source of truth.
- UUID keys.
- Amounts in `BIGINT` minor units.
- Timestamps with time zone.
- Database constraints in addition to application validation.
- Soft delete for financial data, followed by permanent deletion per policy.
- Indexes designed around real filters.

### 11.2 `users` table

Main fields:

```text
id UUID PK
first_name VARCHAR(80) NOT NULL
last_name VARCHAR(80) NOT NULL
username VARCHAR(40) NOT NULL
username_normalized VARCHAR(40) NOT NULL UNIQUE
email VARCHAR(320) NOT NULL
email_normalized VARCHAR(320) NOT NULL UNIQUE
email_verified_at TIMESTAMPTZ NULL
avatar_mode VARCHAR(20) NOT NULL  -- generated/custom
avatar_media_id UUID NULL
avatar_background_color CHAR(7) NOT NULL
avatar_text_color CHAR(7) NOT NULL
locale VARCHAR(16) NOT NULL DEFAULT 'it-IT'
timezone VARCHAR(64) NOT NULL DEFAULT 'Europe/Rome'
theme VARCHAR(16) NOT NULL DEFAULT 'system'
status VARCHAR(20) NOT NULL DEFAULT 'active'
created_at TIMESTAMPTZ NOT NULL
updated_at TIMESTAMPTZ NOT NULL
deleted_at TIMESTAMPTZ NULL
version BIGINT NOT NULL DEFAULT 1
```

Constraints:

- `avatar_mode` within the allowed set;
- colors in hexadecimal format;
- if `avatar_mode=custom`, `avatar_media_id` is not null;
- if `generated`, the media can be null.

### 11.3 `password_credentials` table

```text
user_id UUID PK FK users
password_hash TEXT NOT NULL
password_algorithm VARCHAR(32) NOT NULL
password_updated_at TIMESTAMPTZ NOT NULL
failed_attempts INT NOT NULL DEFAULT 0
locked_until TIMESTAMPTZ NULL
```

The counter can be complemented or replaced by the Redis rate limit, but the persistent security lockout must not depend solely on Redis.

### 11.4 `external_identities` table

```text
id UUID PK
user_id UUID NOT NULL FK users
provider VARCHAR(32) NOT NULL
provider_subject VARCHAR(255) NOT NULL
provider_email VARCHAR(320) NULL
provider_email_verified BOOLEAN NULL
linked_at TIMESTAMPTZ NOT NULL
last_used_at TIMESTAMPTZ NULL
UNIQUE(provider, provider_subject)
UNIQUE(user_id, provider)
```

The constraint guarantees that a Google account is linked to only one application account, and that a user has at most one link per provider.

### 11.5 `sessions` table

```text
id UUID PK
user_id UUID NOT NULL FK users
refresh_token_hash BYTEA NOT NULL UNIQUE
device_name VARCHAR(160) NULL
platform VARCHAR(40) NULL
ip_hash BYTEA NULL
user_agent_hash BYTEA NULL
created_at TIMESTAMPTZ NOT NULL
last_used_at TIMESTAMPTZ NOT NULL
expires_at TIMESTAMPTZ NOT NULL
revoked_at TIMESTAMPTZ NULL
replaced_by_session_id UUID NULL
```

Do not store refresh tokens in plain text.

### 11.6 `wallets` table

```text
id UUID PK
user_id UUID NOT NULL FK users
name VARCHAR(80) NOT NULL DEFAULT 'Main wallet'
currency CHAR(3) NOT NULL DEFAULT 'EUR'
current_balance_minor BIGINT NOT NULL
type VARCHAR(16) NOT NULL DEFAULT 'OTHER'  -- CASH/BANK/OTHER/MEAL_VOUCHER
icon VARCHAR(32) NOT NULL DEFAULT 'wallet'
color CHAR(7) NOT NULL DEFAULT '#6750A4'
created_at TIMESTAMPTZ NOT NULL
updated_at TIMESTAMPTZ NOT NULL
version BIGINT NOT NULL DEFAULT 1
archived_at TIMESTAMPTZ NULL
-- MEAL_VOUCHER only, all four set together (paired NULL-ness CHECKs):
voucher_unit_value_minor INT NULL       -- fixed at creation, never editable afterwards
voucher_expiry_cutoff_month INT NULL    -- 1-12
voucher_expiry_month INT NULL           -- 1-12
voucher_expiry_day INT NULL             -- 1-31
```

Multi-wallet: a user may have more than one active wallet (post-MVP extension of the original single-wallet-per-user rule). The current balance is a denormalized value maintained transactionally. The ability to recompute it from the ledger must be available as an administrative control.

A `MEAL_VOUCHER` wallet's balance is never set directly — it's always the sum of its active lots' remaining quantity × `voucher_unit_value_minor` (§11.14). A voucher loaded in a month at or before `voucher_expiry_cutoff_month` expires on `voucher_expiry_month`/`voucher_expiry_day` of the same year; loaded after, of the following year — the default (month 8, December 31) mirrors the common Italian digital-voucher issuer convention (loaded Jan-Aug → expires Dec 31 same year; loaded Sep-Dec → Dec 31 next year), but every wallet can override it. The three expiry fields stay editable after creation (only affecting future loads); `voucher_unit_value_minor` does not — changing the face value means creating a new wallet.

### 11.7 `categories` table

```text
id UUID PK
owner_user_id UUID NULL
name VARCHAR(80) NOT NULL
name_normalized VARCHAR(80) NOT NULL
direction_scope VARCHAR(16) NOT NULL  -- debit/credit/both
icon_media_id UUID NULL
color CHAR(7) NULL
is_system BOOLEAN NOT NULL DEFAULT FALSE
sort_order INT NOT NULL DEFAULT 0
created_at TIMESTAMPTZ NOT NULL
updated_at TIMESTAMPTZ NOT NULL
archived_at TIMESTAMPTZ NULL
```

Suggested initial categories:

Expenses: Home, Groceries, Dining, Transport, Fuel, Subscriptions, Health, Leisure, Shopping, Taxes, Other.  
Income: Salary, Reimbursement, Gift, Sale, Interest, Other.

### 11.8 `media_assets` table

```text
id UUID PK
owner_user_id UUID NOT NULL FK users
kind VARCHAR(24) NOT NULL  -- profile/transaction/category
source VARCHAR(24) NOT NULL -- upload/search/generated-import
source_provider VARCHAR(40) NULL
source_external_id VARCHAR(255) NULL
source_attribution TEXT NULL
object_key TEXT NOT NULL UNIQUE
original_filename TEXT NULL
mime_type VARCHAR(80) NOT NULL
width INT NOT NULL
height INT NOT NULL
size_bytes BIGINT NOT NULL
sha256 BYTEA NOT NULL
status VARCHAR(24) NOT NULL -- processing/ready/rejected/deleted
created_at TIMESTAMPTZ NOT NULL
last_used_at TIMESTAMPTZ NULL
deleted_at TIMESTAMPTZ NULL
```

Possible deduplication index by user and hash.

### 11.9 `transaction_templates` table

```text
id UUID PK
user_id UUID NOT NULL FK users
direction VARCHAR(8) NOT NULL
title VARCHAR(120) NOT NULL
title_normalized VARCHAR(120) NOT NULL
default_category_id UUID NULL
default_media_id UUID NULL
default_description TEXT NULL
usage_count BIGINT NOT NULL DEFAULT 0
last_used_at TIMESTAMPTZ NULL
created_at TIMESTAMPTZ NOT NULL
updated_at TIMESTAMPTZ NOT NULL
archived_at TIMESTAMPTZ NULL
UNIQUE(user_id, direction, title_normalized) WHERE archived_at IS NULL
```

### 11.10 `transactions` table

```text
id UUID PK
wallet_id UUID NOT NULL FK wallets
user_id UUID NOT NULL FK users
direction VARCHAR(8) NOT NULL
kind VARCHAR(32) NOT NULL
amount_minor BIGINT NOT NULL CHECK (amount_minor > 0)
currency CHAR(3) NOT NULL
title VARCHAR(120) NOT NULL
title_normalized VARCHAR(120) NOT NULL
description TEXT NULL
category_id UUID NULL
template_id UUID NULL
media_id UUID NULL
occurred_at TIMESTAMPTZ NOT NULL
created_at TIMESTAMPTZ NOT NULL
updated_at TIMESTAMPTZ NOT NULL
deleted_at TIMESTAMPTZ NULL
version BIGINT NOT NULL DEFAULT 1
created_by_session_id UUID NULL
idempotency_key UUID NULL
metadata JSONB NOT NULL DEFAULT '{}'
transfer_pair_id UUID NULL FK transactions      -- links a TRANSFER's two rows to each other
linked_transaction_id UUID NULL FK transactions -- links a split meal-voucher expense's two STANDARD legs
system_generated BOOLEAN NOT NULL DEFAULT FALSE -- true only for the automatic "vouchers expired" write-off
UNIQUE(user_id, idempotency_key) WHERE idempotency_key IS NOT NULL
```

Application and database constraints:

- currency equal to the wallet's in the MVP;
- `OPENING_BALANCE` only credit, and only once per wallet;
- `BALANCE_ADJUSTMENT` can be credit or debit;
- title and amount required;
- a deleted transaction does not contribute to the balance;
- `system_generated` rows are never user-editable or user-deletable.

### 11.11 `transaction_audit_events` table

```text
id UUID PK
transaction_id UUID NOT NULL
user_id UUID NOT NULL
action VARCHAR(24) NOT NULL -- created/updated/deleted/restored
before_data JSONB NULL
after_data JSONB NULL
created_at TIMESTAMPTZ NOT NULL
request_id UUID NULL
```

Limit duplicated data and do not include secrets. Retention must be defined.

### 11.12 `idempotency_records` table

```text
user_id UUID NOT NULL
endpoint VARCHAR(160) NOT NULL
key UUID NOT NULL
request_hash BYTEA NOT NULL
response_status INT NOT NULL
response_body JSONB NOT NULL
created_at TIMESTAMPTZ NOT NULL
expires_at TIMESTAMPTZ NOT NULL
PRIMARY KEY(user_id, endpoint, key)
```

### 11.13 Main indexes

```text
transactions(user_id, occurred_at DESC, id DESC) WHERE deleted_at IS NULL
transactions(user_id, direction, occurred_at DESC) WHERE deleted_at IS NULL
transactions(user_id, category_id, occurred_at DESC) WHERE deleted_at IS NULL
transactions(user_id, title_normalized, occurred_at DESC) WHERE deleted_at IS NULL
transactions(wallet_id, occurred_at) WHERE deleted_at IS NULL
transaction_templates(user_id, direction, last_used_at DESC)
media_assets(owner_user_id, last_used_at DESC) WHERE deleted_at IS NULL
sessions(user_id, expires_at) WHERE revoked_at IS NULL
```

For advanced text search, a PostgreSQL trigram index can be added in a later phase. For the MVP, prefix search on the normalized title is sufficient.

### 11.14 `wallet_voucher_lots` table

```text
id UUID PK
wallet_id UUID NOT NULL FK wallets
quantity_total INT NOT NULL CHECK (quantity_total > 0)
quantity_remaining INT NOT NULL CHECK (0 <= quantity_remaining <= quantity_total)
quantity_expired INT NOT NULL DEFAULT 0 CHECK (0 <= quantity_expired <= quantity_total)
expires_at DATE NOT NULL
created_by_transaction_id UUID NOT NULL FK transactions
expired_by_transaction_id UUID NULL FK transactions
created_at TIMESTAMPTZ NOT NULL
```

One row per batch of vouchers loaded in a single operation (wallet creation with an initial quantity, or a later voucher credit), all sharing one `expires_at` computed at load time from the wallet's expiry policy (§11.6). `quantity_remaining` decreases both from spending/removal (recorded in §11.15) and from expiry (`applyVoucherLotExpiry`, no §11.15 row — a loss, not a spend); `quantity_expired`/`expired_by_transaction_id` record how many were lost and which system-generated "vouchers expired" transaction realized it, so the lot stays visible as history once `quantity_remaining` hits 0. Expiry is swept both lazily (on the next mutation touching the wallet) and by a scheduled worker job, so a wallet nobody touches for a long time still ends up correct.

### 11.15 `wallet_voucher_lot_consumptions` table

```text
id UUID PK
transaction_id UUID NOT NULL FK transactions
lot_id UUID NOT NULL FK wallet_voucher_lots
quantity INT NOT NULL CHECK (quantity > 0)
created_at TIMESTAMPTZ NOT NULL
```

Join table recording exactly how many vouchers a transaction (a voucher-expense leg, or a manual voucher removal) drew from each lot it touched, consumed FIFO by `expires_at`. Needed so editing or deleting that transaction can credit the right quantities back to the right lots, even when the original consumption spanned multiple lots or other activity happened on the wallet since.

---

## 12. Redis's role

Redis must be an accelerator and coordinator, not the financial ledger.

### 12.1 Intended uses

- Rate limiting for login, password reset, upload, and API.
- Caching expensive reports.
- Caching title suggestions, if needed.
- Fast revocation or temporary deny-list for tokens.
- Short lock for processing duplicate images.
- Job queue, if a compatible library is adopted.
- Nonces and temporary tickets for Google registration.

### 12.2 Sample keys

```text
ratelimit:login:ip:<hash>
ratelimit:login:user:<normalized>
ratelimit:api:user:<user_id>
auth:google-registration:<token_hash>
cache:report:<user_id>:<wallet_id>:<query_hash>
cache:suggestions:<user_id>:<direction>:<prefix>
lock:media:<sha256>
revoked:jti:<jti>
```

### 12.3 TTL

- Rate limit: minutes to hours depending on policy.
- Google ticket: 5–15 minutes.
- Report: 1–10 minutes, invalidated after mutations.
- Suggestions: short TTL.
- Revocations: until the token expires.

### 12.4 What not to put in Redis as the only copy

- balance;
- transactions;
- profile;
- Google links;
- password hashes;
- permanent image metadata;
- audit.

---

## 13. Reliable balance management

### 13.1 Source of the balance

The transaction ledger is the logical source. `wallets.current_balance_minor` is a denormalized projection for fast reads.

### 13.2 Creating a transaction

Pseudo-flow:

```text
BEGIN;
SELECT wallet FOR UPDATE;
validate ownership and currency;
insert transaction;
compute signed delta;
update wallet balance and version;
insert audit event;
COMMIT;
```

Delta:

```text
CREDIT => +amount_minor
DEBIT  => -amount_minor
```

The response must include:

- the created transaction;
- the new balance;
- the new wallet version.

### 13.3 Editing a transaction

1. Lock the wallet.
2. Read the non-deleted transaction.
3. Check the version.
4. Compute the previous impact.
5. Compute the new impact.
6. Apply `newImpact - oldImpact` to the balance.
7. Update the record and audit.
8. Commit.

### 13.4 Deleting a transaction

1. Lock the wallet.
2. Verify ownership and version.
3. Apply the reverse of the original impact to the balance.
4. Set `deleted_at`.
5. Write the audit entry.
6. Commit.

The initial balance should not be deletable from the ordinary UI; it must be changed via an adjustment or a controlled administrative procedure.

### 13.5 Balance adjustment

Input:

```json
{
  "target_balance_minor": 47000,
  "reason": "Alignment with actual balance",
  "occurred_at": "...",
  "idempotency_key": "..."
}
```

The backend computes the difference inside the transaction after locking the wallet. The client does not send the delta as an authoritative value.

### 13.6 Reconciliation

Add an administrative command or job:

```text
recalculated_balance = sum of all non-deleted transactions
```

Compare the result with `current_balance_minor`. In case of a difference:

- generate an alert;
- do not auto-correct without an audit trail;
- provide a controlled repair command.

### 13.7 Concurrency

- Pessimistic lock on the wallet for balance mutations.
- Optimistic version on transactions and profile.
- Idempotency for network retries.
- PostgreSQL's default isolation level is sufficient with an explicit lock; consider serializable for specific administrative operations.

---

## 14. REST API contract

Prefix: `/v1`  
Format: JSON, except for upload/download.  
Documentation: OpenAPI.

### 14.1 Auth

```http
POST /v1/auth/register
POST /v1/auth/login
POST /v1/auth/refresh
POST /v1/auth/logout
POST /v1/auth/logout-all
POST /v1/auth/password/forgot
POST /v1/auth/password/reset
POST /v1/auth/email/verify
POST /v1/auth/email/resend-verification
POST /v1/auth/google/verify
POST /v1/auth/google/complete-registration
```

### 14.2 Profile

```http
GET    /v1/me
PATCH  /v1/me
DELETE /v1/me
GET    /v1/me/sessions
DELETE /v1/me/sessions/{session_id}
POST   /v1/me/export
GET    /v1/me/export/{export_id}
```

### 14.3 Linked identities

```http
GET    /v1/me/identities
POST   /v1/me/identities/google/link
DELETE /v1/me/identities/google
```

For link and unlink, require recent authentication.

### 14.4 Wallet

Multi-wallet extension: `GET /v1/wallet` is kept for backward compatibility (the caller's oldest active wallet), superseded by the plural endpoints below. `POST /v1/wallets` is served from the transactions module, not wallets, because a non-zero opening balance (or, for `MEAL_VOUCHER`, an initial voucher quantity) must insert the matching ledger row in the same DB transaction as the wallet itself.

```http
GET    /v1/wallet                                    -- legacy single-wallet shape
GET    /v1/wallets
GET    /v1/wallets/{id}
POST   /v1/wallets
PATCH  /v1/wallets/{id}
POST   /v1/wallets/{id}/archive
POST   /v1/wallets/{id}/balance-adjustments           -- not for MEAL_VOUCHER wallets, see below
GET    /v1/wallets/{id}/denominations                 -- CASH only, informational
PUT    /v1/wallets/{id}/denominations
GET    /v1/wallets/{id}/voucher-lots                  -- MEAL_VOUCHER only
POST   /v1/wallets/{id}/voucher-credits                -- MEAL_VOUCHER only
PATCH  /v1/wallets/{id}/voucher-credits/{creditId}
POST   /v1/transfers
PATCH  /v1/transactions/{id}/transfer
```

`GET /v1/wallets/{id}` response (`type` is `CASH`/`BANK`/`OTHER`/`MEAL_VOUCHER`; the `voucher_*` fields are only present for `MEAL_VOUCHER`, §11.6):

```json
{
  "id": "...",
  "name": "Main wallet",
  "currency": "EUR",
  "current_balance_minor": 243050,
  "type": "OTHER",
  "icon": "wallet",
  "color": "#6750A4",
  "version": 42,
  "updated_at": "...",
  "voucher_unit_value_minor": 800,
  "voucher_expiry_cutoff_month": 8,
  "voucher_expiry_month": 12,
  "voucher_expiry_day": 31,
  "voucher_expiring_soon_count": 2
}
```

`POST /v1/wallets/{id}/voucher-credits` takes a signed `quantity` — positive adds a new lot (its `expires_at` computed from the wallet's expiry policy), negative removes vouchers FIFO by expiry, both outside of a purchase (received from an employer, lost, miscounted). `GET /v1/wallets/{id}/voucher-lots` returns every lot (active and expired history, §11.14) — the client buckets them into active/expiring-soon/expired.

A `POST /v1/wallets` or generic-endpoint call against a `MEAL_VOUCHER` wallet where the operation isn't voucher-specific (`balance-adjustments`, `POST /v1/transactions`, `/v1/transfers`) is rejected with `WALLET_IS_MEAL_VOUCHER` — every mutation there must keep the "balance = Σ active lots × voucher_unit_value_minor" invariant, which only the voucher-specific endpoints preserve.

### 14.5 Transactions

```http
GET    /v1/transactions
POST   /v1/transactions
GET    /v1/transactions/{id}
PATCH  /v1/transactions/{id}
PATCH  /v1/transactions/{id}/opening-balance
DELETE /v1/transactions/{id}
POST   /v1/transactions/{id}/restore   -- optional
POST   /v1/voucher-expenses
PATCH  /v1/voucher-expenses/{id}
```

`POST /v1/voucher-expenses` records a purchase paid partly or fully with meal vouchers: `voucher_wallet_id`, `voucher_quantity`, `total_expense_minor`, and — only if the vouchers' value falls short of `total_expense_minor` — `other_wallet_id` for a second linked leg covering the difference. The voucher-wallet leg always debits `voucher_quantity × voucher_unit_value_minor` in full (never just the real cost — the excess is lost, matching real meal-voucher behavior); both legs are `kind=STANDARD` (unlike `TRANSFER`) so they count normally in reports, linked via `linked_transaction_id` (§11.10) rather than `transfer_pair_id`. `PATCH /v1/voucher-expenses/{id}` (addressed by the voucher-wallet leg's id) edits quantity, real cost, difference wallet, and/or date, reversing and recomputing the lot consumption from scratch. `DELETE /v1/transactions/{id}` on either leg of a voucher expense, or on a voucher credit/removal, reverses the associated lot bookkeeping — see §11.14/§11.15.

List parameters:

```text
cursor
limit
direction
kind
category_id
title
amount_min_minor
amount_max_minor
occurred_from
occurred_to
sort
```

Use cursor pagination based on `occurred_at` and `id`.

### 14.6 Suggestions and templates

```http
GET    /v1/transaction-templates?direction=DEBIT&q=bar&limit=10
POST   /v1/transaction-templates
PATCH  /v1/transaction-templates/{id}
DELETE /v1/transaction-templates/{id}
```

Creating a transaction can include:

```json
{
  "template_behavior": "use_existing|create_or_update|none"
}
```

Alternatively, keep the contract simpler and manage the template with a separate endpoint after saving.

### 14.7 Categories

```http
GET  /v1/categories
POST /v1/categories
PATCH /v1/categories/{id}
DELETE /v1/categories/{id}
```

System categories are not deletable; they can be hidden.

### 14.8 Media

```http
GET    /v1/media?kind=transaction&sort=recent
GET    /v1/media/search?q=coffee&page=1
POST   /v1/media/uploads
GET    /v1/media/{id}
DELETE /v1/media/{id}
```

MVP upload: `multipart/form-data` to the backend.  
Evolution: direct upload with a signed URL and a completion callback.

### 14.9 Reports

```http
GET /v1/reports/summary
GET /v1/reports/timeseries
GET /v1/reports/breakdown
GET /v1/reports/monthly-comparison
```

Common parameters:

```text
from
to
timezone
group_by=title|template|category
include_adjustments=false
```

A single aggregated `/v1/reports/dashboard` endpoint could also be created; separate endpoints, however, allow progressive loading and targeted caching.

### 14.10 Health

```http
GET /health/live
GET /health/ready
GET /metrics  -- internal network or authenticated only
```

### 14.11 HTTP codes

- `200` successful read/update.
- `201` creation.
- `204` deletion/logout with no body.
- `400` malformed request.
- `401` not authenticated.
- `403` not authorized.
- `404` resource not found.
- `409` conflict, duplicate, or stale version.
- `413` upload too large.
- `422` domain validation.
- `429` rate limit.
- `500` generic internal error.

---

## 15. Authentication and Google linking

### 15.1 Account model

The application user is the central entity. Local credentials and Google are linkable access methods.

This avoids creating two distinct accounts for the same person and allows:

- adding Google after manual registration;
- using Google on an already-complete account;
- unlinking Google;
- adding Apple or passkeys in the future.

### 15.2 Google verification

The client sends the backend an ID token. The backend must verify at least:

- signature;
- issuer;
- audience against allowed client IDs;
- expiration;
- subject;
- verified-email status, if any.

Do not use unverified email or IDs supplied by the client as proof of identity.

The clients send an ID token issued for the Web OAuth client: Android through `serverClientId`, the web dashboard (Angular, `src/app/core/auth/google-identity.ts`) through Google Identity Services' rendered button, with that same client as `client_id`. One audience in `GOOGLE_CLIENT_IDS` covers both. The Web client lists the dashboard's origin under "Authorized JavaScript origins"; no client secret is used anywhere.

### 15.3 Linking Google to an existing account

1. User already authenticated.
2. Request for recent authentication: password or current provider.
3. Google sign-in.
4. Backend verifies the token.
5. Check that the `provider_subject` is not already linked.
6. Insert into `external_identities`.
7. Audit and security notification.

### 15.4 Unlinking

Allow only if at least one valid access method remains:

- local password set; or
- another linked provider.

Require recent authentication. Revoke any applicable Google tokens and remove the local link.

### 15.5 Password

- Argon2id hash with versioned, upgradable parameters.
- Unique salt.
- Optional pepper stored in the secret manager.
- No passwords in logs.
- Password reset via a single-use, hashed token with a short expiration (30 minutes), delivered as a link (`{APP_PUBLIC_URL}/reset-password?token=…`); a reset revokes every session. Email verification works the same way (24 hours, `/verify-email`).
- Emails are sent over SMTP in the background (`internal/email`), so the response time of "forgot password" doesn't depend on whether the account exists or on the mail server.
- Rate limit for login and reset.
- Messages that don't allow trivial account enumeration.

### 15.6 Mobile sessions

Recommended approach:

- short access token, 10–20 minutes;
- opaque random refresh token, rotated on every use;
- refresh token hash in PostgreSQL;
- token-reuse detection and family revocation;
- access token in the system's secure storage;
- logout revokes the current session;
- logout-all revokes all sessions.

---

## 16. Image management, search, and crop

### 16.1 Sources

- Upload from gallery.
- Camera shot.
- Already-used assets.
- Search via an authorized external provider.

### 16.2 Search provider

Create a backend interface:

```go
type ImageSearchProvider interface {
    Search(ctx context.Context, query string, page int, limit int) ([]SearchResult, error)
    Fetch(ctx context.Context, externalID string) (io.ReadCloser, Metadata, error)
}
```

The client must not send arbitrary URLs to download. It must send a result ID issued by the backend. The backend only accepts allowlisted providers and domains, reducing SSRF risk.

Before choosing the provider, verify:

- license and attribution;
- possibility of permanent storage;
- API limits;
- allowed content;
- commercial availability;
- privacy.

For simple icons, consider a clearly licensed icon catalog; for photographs, a separate stock provider. The abstract interface allows changing providers.

### 16.3 Upload pipeline

1. Requested-size validation.
2. Extension check as only a first filter.
3. Detected MIME check.
4. Signature/magic-bytes check.
5. Image decoding.
6. Pixel-size limit to prevent decompression bombs.
7. Removal of EXIF metadata, especially geolocation.
8. Applying the requested crop.
9. Re-encoding to a supported format.
10. Thumbnail generation.
11. SHA-256 computation.
12. Upload to storage.
13. PostgreSQL metadata insertion.

### 16.4 Formats

Initial allowed inputs:

- JPEG;
- PNG;
- WebP;
- HEIC only if the chosen server pipeline reliably supports it.

Normalized output:

- WebP or JPEG for photos;
- PNG/WebP for images with transparency;
- default sizes for profile and transactions.

### 16.5 Client and server crop

The client produces:

```json
{
  "crop": {
    "x": 0.12,
    "y": 0.08,
    "width": 0.72,
    "height": 0.72,
    "rotation_degrees": 0
  },
  "target_kind": "profile"
}
```

Normalized coordinates between 0 and 1. The backend applies the crop again to the decoded original. In a simpler MVP, the client can upload the already-cropped result directly, but the backend must still re-encode it.

### 16.6 Reuse and deduplication

- Save an asset only when it is selected or uploaded, not for every displayed result.
- Update `last_used_at` when assigned.
- Deduplicate by user and SHA-256.
- Do not physically delete an asset that is still referenced.
- Clean up orphaned assets after a grace period.

### 16.7 Distribution

MVP:

- authenticated endpoint that returns the image;
- private HTTP cache;
- ownership check.

Scalable production:

- short-lived signed URLs;
- CDN;
- private bucket;
- no predictable object key containing personal data.

---

## 17. History, search, and filters

### 17.1 Backend query

The query must always filter by `user_id` derived from the session, never received as an authoritative value from the client.

Logical example:

```sql
SELECT ...
FROM transactions
WHERE user_id = $authenticated_user
  AND deleted_at IS NULL
  AND ($direction IS NULL OR direction = $direction)
  AND ($title IS NULL OR title_normalized LIKE $prefix)
  AND ($min IS NULL OR amount_minor >= $min)
  AND ($max IS NULL OR amount_minor <= $max)
  AND ($from IS NULL OR occurred_at >= $from)
  AND ($to IS NULL OR occurred_at < $to_exclusive)
ORDER BY occurred_at DESC, id DESC
LIMIT $limit_plus_one;
```

### 17.2 Pagination

Prefer cursor pagination:

```text
cursor = base64(occurred_at + id)
```

Advantages:

- stability with new inserts;
- better performance than offset on long histories;
- no significant jumps while scrolling.

### 17.3 Title search

MVP:

- normalization;
- prefix matching;
- client debounce 250–400 ms;
- minimum 2 characters for a remote query.

Evolution:

- trigram similarity;
- typo tolerance;
- search in the description too.

### 17.4 Filtered totals

The list API can return an optional block:

```json
{
  "totals": {
    "credits_minor": 200000,
    "debits_minor": 125000,
    "net_minor": 75000,
    "count": 42
  }
}
```

For very large datasets, compute totals with a separate endpoint or cache.

---

## 18. Reports, percentages, and charts

### 18.1 Period definition

- "Last 30 days": rolling range up to the current moment.
- "Last 12 months": rolling 12 months.
- "Entire history": from the first transaction to the current moment.
- "Custom": local dates chosen by the user.

It is recommended to also add "Current month" and "Current year" for more natural accounting comparisons.

### 18.2 Included transactions

By default:

- include `STANDARD`;
- exclude `OPENING_BALANCE` and `BALANCE_ADJUSTMENT` from ordinary totals;
- show their impact on the balance separately;
- offer an "Include adjustments" toggle.

### 18.3 Summary

Formulas:

```text
total_credits = sum of standard CREDIT
total_debits  = sum of standard DEBIT
net           = total_credits - total_debits
savings_rate  = net / total_credits * 100, if total_credits > 0
```

Starting balance of the period:

```text
balance immediately before "from"
```

Ending balance:

```text
starting balance + impact of all transactions in the period, including adjustments
```

### 18.4 Percentages by title

Required rule:

- multiple transactions with the same title must be a single entry;
- if `template_id` exists, group by template;
- otherwise group by `title_normalized`;
- display the template's canonical title or the most recent title.

For expenses:

```text
entry_percentage = total_entry_expenses / total_period_expenses * 100
```

For income, use a separate denominator. Do not add income and expenses into a single pie, since they have opposite meanings.

### 18.5 Percentages by category

Same formula, grouping by category. Transactions with no category go into "Other."

### 18.6 Small entries

To avoid unreadable charts:

- show at most 6–8 main entries;
- aggregate the rest into "Other";
- allow opening the full list;
- show amount, percentage, and transaction count.

### 18.7 Monthly comparison

Conceptual query:

```sql
SELECT date_trunc('month', occurred_at AT TIME ZONE $timezone) AS month,
       SUM(CASE WHEN direction='CREDIT' AND kind='STANDARD' THEN amount_minor ELSE 0 END) AS credits,
       SUM(CASE WHEN direction='DEBIT'  AND kind='STANDARD' THEN amount_minor ELSE 0 END) AS debits
FROM transactions
WHERE ...
GROUP BY month
ORDER BY month;
```

The backend must fill months with no transactions with zero, to keep the chart continuous.

### 18.8 "Single month" rule

If the period touches only a single calendar month:

- do not show the monthly comparison;
- show a daily trend and breakdown instead;
- avoid an empty card or a redundant message.

### 18.9 Report caching

Cache key based on:

- user;
- wallet;
- range;
- time zone;
- grouping;
- adjustments flag;
- balance version or last-mutation timestamp.

After create/update/delete transaction:

- increment a report version per wallet; or
- invalidate known keys; or
- use a short TTL with the version in the key.

The versioned approach avoids Redis key scans.

### 18.10 Accuracy

- Monetary calculations in integers.
- Percentages computed with decimal precision and rounded only for display.
- The sum of displayed percentages may not be exactly 100 due to rounding; "Other" can absorb the remainder.
- Test daylight-saving-time changes and month boundaries in the `Europe/Rome` time zone.

---

## 19. Security

### 19.1 Object-level authorization

Every endpoint that uses an ID must verify that the resource belongs to the authenticated user. It's not enough for the ID to exist.

Recommended repository pattern:

```text
GetTransactionByIDAndUserID(transactionID, authenticatedUserID)
```

Do not expose methods that fetch a record by ID and delegate the check to the client.

### 19.2 Input validation

- Strict schema and types.
- Length limits.
- Enums for direction and nature.
- Amount ranges.
- Reasonable dates.
- Upload MIME and size.
- Reject unexpected properties when appropriate.
- Server-side business validations.

### 19.3 Transport

- HTTPS only in production.
- HSTS at the reverse proxy.
- No PostgreSQL or Redis port exposed publicly.
- Certificates with automatic renewal.

Implemented: the host's Caddy on the `alex-violatto` VPS terminates TLS for `financialmanager.alexviolatto.dev` with automatic Let's Encrypt certificates, redirects http to https and sends `Strict-Transport-Security: max-age=31536000; includeSubDomains`; it forwards `/api/*` to the API on `127.0.0.1:10003` with the prefix stripped and answers 404 on `/api/metrics` (section 22.1). The site block is `financial-manager-backend/deploy/Caddyfile.example`. Android release builds refuse cleartext traffic: only the debug manifest sets `usesCleartextTraffic`, for the local backend on the emulator. See `docs/build-deploy.md`.

The web dashboard (section 9.9) gets a Content-Security-Policy from Caddy: scripts only from its own origin plus Google's sign-in client, no inline scripts and no `eval` of any kind (no `'unsafe-eval'`, no `'wasm-unsafe-eval'`), inline styles (Angular component styles and chart positioning), fonts only from its own origin, `frame-ancestors 'none'`; plus `nosniff`, a referrer policy and a Permissions-Policy. Everything the page loads is served by the dashboard itself, no CDN. To fit the policy the build disables `inlineCritical` (it adds an inline `onload` handler) and ICU messages are formatted without compiling code. The Playwright smoke tests serve the build with this exact policy, so a violation fails CI. The API sends CORS headers only to origins in `CORS_ALLOWED_ORIGINS`, empty in production and in development (the dashboard's dev server proxies `/api`).

### 19.4 Secrets

- Secret manager in production.
- `.env` local only, never committed.
- Key rotation.
- Distinct keys per environment.
- No secrets in logs or Docker images.

### 19.5 Rate limiting

Scopes:

- IP;
- normalized username/email;
- authenticated user ID;
- sensitive endpoints;
- image upload and search.

Apply stricter limits to login, password reset, email verification, and the Google exchange.

Client IP behind the reverse proxy: chi's `RealIP` is not used, because it trusts `X-Forwarded-For`/`X-Real-IP` from anyone. `httpserver.RealIP` reads `X-Forwarded-For` only when the TCP peer is inside `TRUSTED_PROXY_CIDRS` (in production `172.16.0.0/12`, the Docker bridge Caddy connects through) and takes the rightmost untrusted address; with the variable empty the TCP peer is the client. Nothing stores the address yet: the password login computes `clientIPHash` (host only, without the port) but does not persist it, and `sessions.ip_hash` stays NULL; recording it, and doing so for the Google exchange too, is open work.

### 19.6 Upload

- Format allowlist.
- Byte and pixel limits.
- Re-encoding.
- Server-generated filename.
- Private bucket.
- No execution of the content.
- Malware scanning if the infrastructure allows it.
- Timeouts and CPU/memory limits for processing.

### 19.7 Secure logging

Do not log:

- passwords;
- tokens;
- Google ID tokens;
- refresh tokens;
- transaction descriptions by default;
- full amounts if not needed;
- signed URLs.

Log:

- request ID;
- endpoint;
- status;
- latency;
- pseudonymized or internal user ID;
- authentication outcome;
- provider-linking events;
- error code.

### 19.8 Dependencies

- Lockfile.
- Vulnerability scanning for Go and Docker images.
- Automatic updates via PR, no automatic deploy without tests.
- SBOM for backend releases.

---

## 20. Privacy and data management

This section is a technical and product requirement; final legal decisions must be validated for the distribution markets.

### 20.1 Minimization

- Keep only necessary data.
- Do not save the generated avatar as a file.
- Strip EXIF from images.
- Do not import unnecessary Google data.
- Request minimal Google scopes for authentication.

### 20.2 Export

CSV format:

```text
id,date_time,type,title,category,description,amount,currency,nature
```

JSON format:

- profile;
- wallet;
- custom categories;
- templates;
- transactions;
- image references or a separate archive;
- the AI personal context (`contesto_analisi_ai`) and the AI analysis history (`analisi_ai`, sections 32 and 33): every analysis with its period, wallets, options, provider and model (and how it ran, for on-device ones), status and tokens, and its whole conversation (the data that was sent, the report, the questions and the answers). Never the system prompt or API keys. A pending row past its window is exported as failed, as the app shows it. Results still waiting on a phone (section 33.9) are not on the server and so not in the export.

### 20.3 Account deletion

Flow:

1. Recent authentication request.
2. Irreversibility warning.
3. Possible grace period.
4. Session revocation.
5. Provider unlinking.
6. Marking the account as pending deletion.
7. Data and asset removal job.
8. Minimal separate audit only if required by policy.

### 20.4 Backup

Deletion from backups requires a documented policy. Backups must have a finite retention and restricted access.

---

## 21. Docker and environments

### 21.1 Environments

- `local`: individual development.
- `test`: automated integration.
- `staging`: functional replica of production.
- `production`: real data.

### 21.2 Compose strategy

Recommended files:

```text
compose.yaml
compose.dev.yaml
compose.prod.yaml
.env.example
```

`compose.yaml` defines services, networks, volumes, and healthchecks. Overrides define ports and environment differences.

### 21.3 Required port mapping

Development environment:

```yaml
services:
  postgres:
    ports:
      - "127.0.0.1:${POSTGRES_HOST_PORT:-10001}:5432"

  redis:
    ports:
      - "127.0.0.1:${REDIS_HOST_PORT:-10002}:6379"

  api:
    ports:
      - "127.0.0.1:${API_HOST_PORT:-10003}:8080"

  object-storage:
    ports:
      - "127.0.0.1:${OBJECT_STORAGE_HOST_PORT:-10004}:9000"
```

The development stack also runs Mailpit (`127.0.0.1:${MAILPIT_HOST_PORT:-10006}` → 8025, web UI only), which receives every email the local API sends.

In production it's preferable not to publish PostgreSQL and Redis. If an operational requirement mandates host ports, bind them at least to loopback or a private network:

```yaml
- "127.0.0.1:10001:5432"
- "127.0.0.1:10002:6379"
```

The API can listen on `10003`, ideally behind a TLS reverse proxy on `443`. In production it is published on `127.0.0.1:10003` only (`API_HOST_BIND=127.0.0.1`) and reached through the host's Caddy (section 19.3). MinIO is exposed on `10004` for local host-run tooling and integration tests only; services inside Docker still use `object-storage:9000`.

### 21.4 Services

```text
api
worker
postgres
redis
object-storage
web             -- production: the Angular web dashboard (image from Docker Hub, built by CI)
reverse-proxy   -- production (Caddy on the host)
```

`object-storage` runs `dokjolly/minio:RELEASE.2025-10-15T17-29-55Z-r1`: MinIO stopped publishing community images in October 2025 and removed `minio/minio`/`minio/mc` from Docker Hub, so the last upstream release is rebuilt from source in github.com/Dokjolly0/minio (with `dokjolly/mc` for the backup scripts). It reads the data written by the former `minio/minio` image unchanged. MinIO itself no longer gets fixes; it is only reachable on `backend_internal`, and a maintained S3-compatible store is the long-term option.

### 21.5 Networks

- `backend_internal`: API, worker, PostgreSQL, Redis, object storage.
- `edge`: reverse proxy and API.
- Database and Redis not connected to the edge network.

In production the reverse proxy is Caddy installed on the host (it also serves other sites), not a container: it reaches the API through the published loopback port, so the `edge` network only carries the API.

Containers communicate using the service name and internal port, not the host port:

```text
postgres:5432
redis:6379
api:8080
object-storage:9000
```

### 21.6 Volumes

- `postgres_data`.
- `object_storage_data`.
- Redis may have no persistence if used only for cache/rate limit; consider it if it hosts a job queue or non-reconstructible session metadata.

### 21.7 Healthcheck

- PostgreSQL: `pg_isready`.
- Redis: `redis-cli ping` with authentication.
- API live: process active.
- API ready: PostgreSQL connection available; Redis can be degradable for some functions, per policy.
- Object storage: bucket accessible.

### 21.8 Go Dockerfile

- Multi-stage build.
- Minimal runtime image.
- Non-root user.
- Static binary when possible.
- `read_only` filesystem, with explicit temp directories.
- External healthcheck or dedicated endpoint.

### 21.9 Migrations

Do not run concurrent migrations from every API replica. Options:

- separate job before deploy;
- `migrate` command run only once;
- PostgreSQL advisory lock as extra protection.

Migrations must be backward-compatible when doing a rolling deployment.

### 21.10 Backup

- Automatic PostgreSQL backup.
- Periodic restore test.
- Object storage backup.
- Backup encryption.
- Retention per environment.
- Redis is not part of the main financial backup.

---

## 22. Observability, logging, and monitoring

### 22.1 Backend metrics

- requests per endpoint/status;
- p50/p95/p99 latency;
- error rate;
- PostgreSQL pool connections;
- slow queries;
- Redis cache hit/miss;
- rate limits triggered;
- rejected uploads;
- image processing time;
- failed jobs;
- differences detected by balance reconciliation.

### 22.2 Tracing

Propagate a `request_id` or trace ID:

- Flutter → API;
- handler → service → repository;
- API → image provider/object storage.

### 22.3 Alerts

- API not ready.
- Error rate above threshold.
- Database storage near the limit.
- Backup failed.
- Reconciliation mismatch.
- Spike in failed logins.
- Job queue stuck.

### 22.4 Client crashes

Integrate a provider through an abstraction. Strip personal data and transaction content before sending.

---

## 23. Test strategy

### 23.1 Backend unit tests

Test:

- transaction impact calculation;
- direction/amount change;
- target-balance adjustment;
- title normalization;
- report grouping;
- percentages;
- period limits;
- Google unlink rules;
- image validations.

### 23.2 Backend integration tests

With real PostgreSQL and Redis in containers:

- create/update/delete and balance;
- rollback on error;
- concurrency on two inserts;
- idempotency key;
- unique Google subject;
- history filters;
- cursor pagination;
- monthly reports;
- cache invalidation;
- up/down migrations where supported.

### 23.3 Contract tests

- Validate requests and responses against OpenAPI.
- Generate a client or mock server.
- Block unversioned breaking changes.

### 23.4 Flutter unit tests

- ViewModel.
- `Money` formatting.
- error mapping.
- filter query construction.
- session state.
- suggestion handling.

### 23.5 Widget tests

- registration form;
- new transaction;
- filters;
- loading/error/empty states;
- themes;
- text scaling;
- generated avatar.

### 23.6 Golden tests

Key screens in:

- light theme;
- dark theme;
- normal and enlarged text;
- small and large viewports.

### 23.7 End-to-end

Minimum scenarios:

1. Manual registration with initial balance.
2. Login and logout.
3. Complete Google registration.
4. Entering an expense with an image.
5. Entering income via a template.
6. Editing a transaction and verifying the balance.
7. Deletion and balance verification.
8. Balance adjustment.
9. History filters.
10. Report over multiple months.
11. Google linking and unlinking.
12. Data export.

### 23.8 Security

- BOLA/IDOR: attempting access to other users' transactions.
- brute force and rate limit.
- expired/revoked tokens.
- refresh token reuse.
- upload with fake MIME.
- huge images/decompression bombs.
- arbitrary URLs in media search.
- mass assignment.
- SQL injection.
- logging of secrets.

### 23.9 Performance

Synthetic datasets:

- 10,000 transactions per user;
- 1,000 active test users;
- reports over multiple years;
- combined filters;
- concurrent uploads.

Initial targets to validate:

- common reads p95 under 300 ms at the API level under nominal conditions;
- mutations p95 under 500 ms excluding upload;
- cached reports p95 under 250 ms;
- non-cached reports reasonable and with a controlled timeout.

---

### 23.10 Web dashboard

- Unit and component tests with Vitest (`ng test`): session refresh (single flight, Web Lock, multi-tab sign-out), SSE parser, money parsing and formatting, error mapping, the ICU transpiler over every ARB message, "Aggiungi" rules, AI periods.
- Build-script tests (`node --test`): ARB conversion, missing keys and placeholder mismatches.
- Browser smoke tests with Playwright on desktop Chrome and a Pixel 7 profile, against the production build with the API mocked in the browser and the production CSP enforced: login → home → new operation → history search → reports.
- Manual pass against the real backend before a release: the feature-parity list of section 9.9 in light and dark, Italian and English, desktop and 375 px.

## 24. CI/CD and release

### 24.1 Flutter pipeline

- format check;
- analyze;
- unit tests;
- widget tests;
- selected golden tests;
- Android/iOS build for release branches;
- signing only in a protected environment;
- distribution to testers.

Implemented in `mobile-ci.yml`: format, analyze, tests, debug and release APK (with size analysis), unsigned iOS build.

Web dashboard pipeline, `web-ci.yml` (on changes to `financial-manager-web/`, the app's ARB files or the Caddy example): Prettier check, ESLint, Vitest, build-script tests, production build, Playwright smoke tests (report kept as an artifact on failure); then the Docker image, built on every run and published to Docker Hub (`dokjolly/financial-manager-web:latest` and `:sha-<commit>`) on `main`, with the `DOCKERHUB_USERNAME`/`DOCKERHUB_TOKEN` secrets.

Android signing (implemented): one upload keystore signs release and debug builds on every PC, so Google Sign-In needs a single SHA-1 and APKs built anywhere update each other. `android/app/build.gradle.kts` reads its path and passwords from `android/key.properties` (never committed; `key.properties.example` shows the fields); without it builds fall back to the local debug key, which is what CI does today. For the Play Store the keystore is the upload key of Play App Signing, and the SHA-1 of Google's app signing key gets its own Android OAuth client. Signing in CI from GitHub Secrets is documented as future work in `docs/build-deploy.md`.

### 24.2 Go pipeline

- `go fmt`/format check;
- `go vet`;
- tests with race detector where applicable;
- integration tests;
- vulnerability scan;
- OpenAPI validation;
- Docker image build;
- image scan;
- SBOM;
- registry push.

Implemented in `backend-ci.yml`: gofmt, `go vet`, `go test -race`, govulncheck (fails on vulnerabilities the code reaches), Redocly lint of the OpenAPI contract, then the API and worker image builds scanned by Trivy (HIGH/CRITICAL with a fix fail the build). The Go release comes from go.mod's `toolchain` directive (latest patch, for the standard library's security fixes); images build on `golang:1.27-alpine3.24` and run on `alpine:3.24`. Both workflows run on `ubuntu-26.04` with actions on Node 24; third-party actions that had their tags moved (`trivy-action`) are pinned to a commit. Registry push and SBOM are not done for the Go images (they build on the VPS); the web dashboard image is pushed by `web-ci.yml` (section 24.1).

### 24.3 Deploy

Production runs on the `alex-violatto` VPS (`/projects/FinancialManager`, Docker Compose behind the host's Caddy); `docs/build-deploy.md` has the procedure, including moving the stack to another VPS (database dump plus the MinIO volume, same `.env`). Updates run with `financial-manager-backend/scripts/deploy.sh`: `git pull`, Go images built one at a time on the VPS, the dashboard image pulled from Docker Hub, `up -d` (migrations first), readiness check.

1. Backup or verification of a recent backup.
2. Running compatible migrations.
3. Backend deploy.
4. Readiness check.
5. Smoke test.
6. Worker deploy.
7. Error monitoring.
8. Application rollback if needed.

### 24.4 API versioning

- `/v1` in the path.
- Additive changes that don't break clients.
- New fields optional.
- Documented deprecations.
- Minimum supported app version defined via remote config or a compatibility endpoint.

---

## 25. Implementation roadmap

The roadmap is expressed in phases and deliverables. The actual duration depends on team size, required quality, and platform coverage.

### Phase 0 — Discovery and architectural decisions

Deliverables:

- final requirements approved;
- glossary;
- low-fidelity wireframes;
- image provider choice;
- Google-only account decision yes/no;
- ADR for state management, image storage, and session auth;
- initial OpenAPI spec;
- initial data schema;
- threat model.

### Phase 1 — Foundations

Backend:

- Go repository;
- config;
- logging;
- PostgreSQL/Redis;
- migrations;
- health endpoint;
- Docker Compose;
- CI.

Flutter:

- repository;
- theme;
- routing;
- localization;
- network client;
- error handling;
- initial component library.

### Phase 2 — Account and onboarding

- manual registration;
- email verification;
- login;
- refresh/logout;
- profile;
- generated avatar;
- initial balance;
- password recovery;
- authentication E2E tests.

### Phase 3 — Google Identity

- Android/iOS client configuration;
- server-side token verification;
- incomplete registration;
- linking;
- unlinking;
- anti-duplicate constraints;
- audit and security notifications.

### Phase 4 — Ledger and Home

- wallet;
- standard transactions;
- atomic balance update;
- home;
- recent list;
- detail;
- edit;
- deletion;
- balance adjustment;
- reconciliation.

### Phase 5 — Templates, categories, and history

- system categories;
- custom categories;
- transaction templates;
- autocomplete;
- filters;
- cursor pagination;
- empty/error UX;
- large-dataset testing.

### Phase 6 — Media

- storage;
- upload;
- crop;
- re-encoding;
- image library;
- provider search;
- deduplication;
- asset cleanup.

### Phase 7 — Reports

- summary;
- timeseries;
- breakdown by title/template;
- breakdown by category;
- monthly comparison;
- Redis caching;
- Flutter charts;
- accessibility and alternative table.

### Phase 8 — Advanced account and data

- active sessions;
- logout-all;
- password change;
- preferences;
- CSV/JSON export;
- account deletion.

### Phase 9 — Hardening and release

- security testing;
- performance testing;
- backup/restore;
- observability;
- privacy review;
- beta;
- bug fixing;
- store readiness;
- operational runbook.

### Phase 10 — Post-MVP

- recurrences;
- notifications;
- budgets;
- multiple wallets;
- CSV import;
- passkeys;
- offline write sync.

### Phase 11 — AI analysis

See section 32.

- wallet purpose;
- encrypted per-user provider keys and settings;
- provider adapters with streaming;
- prompt builder and preview;
- streamed analyses, follow-ups and history;
- consent and privacy notice update.

---

## 26. Acceptance criteria

### 26.1 Initial balance

- A user cannot complete registration with a negative initial balance.
- The initial balance generates an `OPENING_BALANCE` record.
- The balance shown on the home screen matches the created wallet.
- Retrying registration does not duplicate the initial balance.

### 26.2 New transaction

- Amount and title are required.
- The amount must be positive.
- The default date matches the current moment in the user's time zone.
- Date editable via a date/time picker.
- The balance is updated atomically.
- Double taps or retries don't create duplicates.
- The image is optional.
- The title suggests templates compatible with the direction.

### 26.3 Editing

- Changing the amount updates the balance by the difference.
- Changing the direction applies the full difference.
- Version conflict produces a 409 error.
- The audit contains before and after.

### 26.4 Deletion

- The transaction disappears from ordinary history.
- The balance is correctly restored.
- The deletion is tracked.
- The initial balance cannot be deleted from the ordinary UI.

### 26.5 Adjustment

- The user enters the desired balance.
- The backend computes the delta.
- The adjustment appears in history.
- Ordinary reports exclude it by default.

### 26.6 History

- All filters can be combined.
- A minimum amount greater than the maximum produces a validation error.
- Reversed dates produce a validation error.
- Pagination doesn't duplicate or skip records under normal conditions.
- Search never returns other users' data.

### 26.7 Reports

- Multiple transactions from the same template are aggregated.
- The fallback uses the normalized title.
- Income and expenses have separate percentages.
- The monthly comparison is absent with a single month.
- Empty months are represented with zero.
- Adjustments and initial balance are handled according to the flag.

### 26.8 Google

- A `provider_subject` can belong to only one user.
- A new Google user must complete the required fields.
- Unlinking is prevented if it would leave the user with no access method.
- An invalid ID token or one with the wrong audience is rejected.

### 26.9 Images

- Disallowed files are rejected.
- Accepted images are re-encoded.
- EXIF is stripped.
- Profile crop is 1:1.
- An already-used asset can be selected without a new upload.
- The backend does not download arbitrary URLs.

---

## 27. Risks and mitigations

| Risk | Impact | Mitigation |
|---|---:|---|
| Inconsistent balance after retry or concurrency | High | DB transaction, row lock, idempotency key, reconciliation |
| Duplicate Google/manual accounts | High | Central user entity, unique provider subject, explicit linking |
| User locked out after unlink | High | Prevent unlink without an alternative method |
| Slow reports on large history | Medium/High | Indexes, dedicated queries, versioned cache, performance tests |
| Image search with license issues | High | Provider adapter, terms review, attribution, allowlist |
| Malicious or huge uploads | High | Byte/pixel limits, magic bytes, decode/re-encode, timeout |
| Redis used as source of truth | High | PostgreSQL authoritative, Redis accessory only |
| Registration UI too long | Medium | Step-based flow and Google pre-fill |
| Similar titles fragment reports | Medium | Templates, normalized title, categories |
| Wrong dates at month/DST boundaries | Medium | UTC storage, explicit time zone, Europe/Rome tests |
| Editing/deleting alters historical reports | Expected | Audit, soft delete, cache invalidation |
| Excessive dependency on a Flutter library | Medium | Wrapper, ADR, spike and testing before adoption |
| Exposed DB/Redis ports | High | Loopback/private-network bind, firewall, auth, internal-only in production |

---

## 28. Decisions to confirm before development

These decisions do not block the plan, but must be closed in Phase 0.

1. **Initial platforms:** Android and iOS, or also web/desktop.
2. **Google-only account:** allowed, or local password always required.
3. **Negative balance after registration:** allowed, recommended yes.
4. **Image search provider:** icons, photographs, or both.
5. **Categories:** required with default "Other," or fully optional.
6. **Description visibility in logs and crash reports:** recommended never.
7. **"Last month" period:** last 30 days or the previous calendar month. The plan uses "Last 30 days."
8. **Deletion:** immediate undo and/or a visible trash.
9. **Image export:** included in the archive or references only.
10. **Email notifications:** verification, reset, security, export ready. *Decided (October 2026):* verification and password reset only, over SMTP with presets for Gmail (app password) and Infomaniak and settings for any other server; Mailpit in development. Security and export emails are not sent.
11. **Production storage:** self-hosted MinIO or cloud bucket.
12. **Offline support:** read-only in the MVP, or queued writes.
13. **Default report grouping:** category or title/template. To honor the draft, the default can be title/template with a category tab.

---

## 29. Recommended repository structure

Recommended choice: two main repositories, plus an optional one for infrastructure.

```text
economy-app-mobile/
├── lib/
├── test/
├── integration_test/
├── android/
├── ios/
├── assets/
├── pubspec.yaml
└── README.md

economy-app-backend/
├── cmd/
├── internal/
├── migrations/
├── openapi/
├── tests/
├── Dockerfile
├── compose.yaml
├── compose.dev.yaml
├── compose.prod.yaml
├── .env.example
└── README.md

economy-app-infra/            -- optional
├── reverse-proxy/
├── monitoring/
├── backup/
└── deployment/
```

Alternatively, a monorepo suits a small team:

```text
/apps/mobile
/services/backend
/infra
/docs
```

A monorepo makes coordinated OpenAPI/client changes easier; separate repositories reduce organizational coupling. The choice should be recorded as an ADR.

Implemented: a monorepo.

```text
financial-manager-backend/   -- Go API and worker, migrations, OpenAPI, compose files, deploy/
financial-manager-app/       -- Flutter client (Android, iOS); lib/l10n/*.arb shared with the web
financial-manager-web/       -- Angular web dashboard, its Dockerfile and docker/ (Caddy, assetlinks)
docs/                        -- build and deploy, privacy, AI spike
.github/workflows/           -- backend-ci, mobile-ci, web-ci
plan.md
```

---

## 30. Definition of Done

A feature is complete only when:

- requirements and acceptance criteria are met;
- design approved and implemented in both themes;
- client and server validations are present;
- authorization is verified;
- unit and integration tests pass;
- OpenAPI is updated;
- migrations are present and reviewed;
- logs and metrics are adequate;
- errors and empty states are handled;
- accessibility is verified;
- no secrets or personal data in logs;
- documentation is updated;
- the feature is tested on a real device;
- rollback or compatibility handling is defined;
- code review is complete.

---

## 31. Technical references

The plan's choices are consistent with the following official sources and guidelines:

- Flutter — Guide to app architecture: https://docs.flutter.dev/app-architecture/guide
- Flutter — Architecture concepts: https://docs.flutter.dev/app-architecture/concepts
- Flutter — Offline-first support: https://docs.flutter.dev/app-architecture/design-patterns/offline-first
- Go — Accessing relational databases: https://go.dev/doc/database/
- Go — Executing transactions: https://go.dev/doc/database/execute-transactions
- Google — Authenticate with a backend server: https://developers.google.com/identity/sign-in/android/backend-auth
- Google — OpenID Connect: https://developers.google.com/identity/openid-connect/openid-connect
- PostgreSQL — Constraints: https://www.postgresql.org/docs/current/ddl-constraints.html
- Docker — Compose networking: https://docs.docker.com/compose/how-tos/networking/
- Docker — Publishing ports: https://docs.docker.com/get-started/docker-concepts/running-containers/publishing-ports/
- Redis — Rate limiting with Go: https://redis.io/docs/latest/develop/use-cases/rate-limiter/go/
- Redis — Cache-aside: https://redis.io/docs/latest/develop/use-cases/cache-aside/
- OWASP — API Security Top 10: https://owasp.org/API-Security/editions/2023/en/0x11-t10/
- OWASP — Password Storage Cheat Sheet: https://cheatsheetseries.owasp.org/cheatsheets/Password_Storage_Cheat_Sheet.html
- OWASP — File Upload Cheat Sheet: https://cheatsheetseries.owasp.org/cheatsheets/File_Upload_Cheat_Sheet.html
- OWASP — REST Security Cheat Sheet: https://cheatsheetseries.owasp.org/cheatsheets/REST_Security_Cheat_Sheet.html
- OpenAPI Specification: https://spec.openapis.org/oas/

---

## 32. AI analysis (Analisi AI)

An optional feature that sends a summary of the user's ledger to a large language model (LLM) chosen by the user, with the user's own API key, and shows back a written report with follow-up questions. It is off until the user configures a provider and accepts the disclosure.

### 32.1 Goals and non-goals

Goals:

- a personalized, readable report on spending, income, anomalies, savings opportunities, recurring payments and wallet usage;
- the user decides the provider, the model, the period, the wallets and how much data leaves the server;
- the user can see exactly what is sent before sending it, and can edit the instructions;
- every analysis is kept in a history with its follow-up conversation and token usage.

Non-goals:

- no regulated financial advice: the system prompt frames the output as informational;
- no model tools or actions: the model only reads data and writes text, it can never change the ledger;
- no shared, instance-wide API key: every user brings their own;
- no built-in price table: prices drift across providers, so cost is shown only when the user enters their prices.

### 32.2 Privacy and consent

- Before the first preview the app shows a consent sheet: the chosen provider is a third party; what is sent (aggregates, wallet names and purposes, optional transaction list, personal context); what is never sent (email, name, account identifiers, images); the provider's own retention policy applies; how to revoke.
- Consent is versioned with `ai.ConsentVersion`. Preview and run return `403 AI_CONSENT_REQUIRED` when the stored version is older. The constant is bumped whenever the disclosure text changes.
- Data minimization by default: aggregates only. The raw transaction list is opt-in, capped (default 200, max 500, newest first) and titles can be replaced by stable pseudonyms (`Voce 1..N`).
- The API key is encrypted at rest with AES-256-GCM (`internal/platform/secretbox`), key from `AI_KEY_ENCRYPTION_KEY`, additional authenticated data `user_id || provider || base_url`. Responses only carry a masked hint (`sk-…a1b2`). Keys are never logged or exported.
- Everything is deleted with the account (`ON DELETE CASCADE`). The user can delete single analyses or the whole history, and remove stored keys.
- `docs/privacy.md` describes the feature in its own section.

### 32.3 Data model

- `wallets.purpose VARCHAR(280) NULL`: what the wallet is for ("spese quotidiane", "fondo emergenze"). Editable from the wallet form and from the AI settings.
- `ai_provider_credentials`: one row per (user, provider, base_url) so switching provider does not mean retyping a key. Provider is `anthropic`, `openai`, `gemini` or `openai_compatible` (the last requires `base_url`). Encrypted key, nonce, key version, hint, last test result.
- `ai_settings`: one row per user: active credential, model, consent version and date, defaults for the analysis options, `max_output_tokens`, optional prices per million tokens, `version` for optimistic locking.
- `ai_user_context`: one row per user: household size, income type, free text "about me", goals, things to ignore, response style.
- `ai_analyses`: preset, period, timezone, wallet ids, options (including `lang`, the prompt language set by the server, which follow-ups use for their rules; older rows without it use the user's current locale), provider, model, the provider account it ran with (`credential_id`, `ON DELETE SET NULL`), prompt version, data fingerprint, status (`STREAMING`, `COMPLETED`, `FAILED`, `CANCELLED`), error code, token totals, `client_request_id` (unique per user, replaces the idempotency header on SSE routes).
- `ai_messages`: ordered messages of an analysis, kind `CONTEXT` (the exact data block and instructions sent), `REPORT`, `QUESTION`, `ANSWER`, with per-message tokens and status. Follow-ups replay the stored messages and never recompute the data, so answers stay consistent with the report.

### 32.4 API

All routes require authentication. JSON routes keep the normal request timeout; the two streaming routes live in a separate group without it, bounded by `AI_STREAM_MAX_DURATION` (default 5m) and an idle watchdog `AI_STREAM_IDLE_TIMEOUT` (default 90s).

| Method and path | Purpose |
|---|---|
| `GET /v1/ai/settings` | settings, key hint, consent, setup checklist status, stored credentials |
| `PUT /v1/ai/settings` | provider, base URL, model, key (omitted keeps it, empty string clears it), limits, defaults, prices |
| `DELETE /v1/ai/credentials/{id}` | forget a stored key |
| `POST /v1/ai/settings/test` | test a configuration, saved or not, and report latency |
| `POST /v1/ai/models` | list the provider's models (POST because the body may carry a key) |
| `PUT /v1/ai/consent`, `DELETE /v1/ai/consent` | accept or revoke |
| `GET /v1/ai/context`, `PUT /v1/ai/context` | personal context |
| `GET /v1/ai/presets` | localized presets with default instructions and sections |
| `POST /v1/ai/analyses/preview` | build the prompt without sending it |
| `POST /v1/ai/analyses` | run an analysis, Server-Sent Events |
| `POST /v1/ai/analyses/{id}/messages` | follow-up question, Server-Sent Events |
| `GET /v1/ai/analyses` | history, cursor paginated |
| `GET`, `PATCH`, `DELETE /v1/ai/analyses/{id}` | detail with messages, rename, delete |
| `DELETE /v1/ai/analyses` | delete the whole history |

Streaming events: `meta` (analysis and message ids), `delta` (text, coalesced about every 50 ms), `usage`, `done`, `error`; a `: ping` comment every 15 s keeps proxies from closing the connection. Errors detected before the first byte are normal JSON error envelopes. If the client disconnects, the upstream call is cancelled and the partial text is saved with status `CANCELLED`.

Preview and run share the same request body. A cloud run may pick any of the user's stored provider accounts with `credential_id` (one that has a model and, when the provider needs one, a key); without it the active account runs. The account is stored on the analysis and its follow-ups keep using it, falling back to the active one if it was removed. The setup screen lists every such account and every model installed on the phone (section 33), so the user switches model per analysis without touching the settings; picking a phone model makes it the phone's active model. The picker starts on the model the account last ran an analysis with on this phone (stored on the device per account, written when the preview succeeds) while it is still available, else on the saved mode's model. The preview returns a `data_fingerprint` (SHA-256 of the rendered data block and prompt version). The run sends it back; if the data changed in between the server answers `409 AI_DATA_CHANGED` and the app previews again. The server always rebuilds the data block from the database: the client can only edit the instructions.

On-device analyses (section 33) add `PUT /v1/ai/mode`, a `scope` on the consent routes, `target` and `device` on the preview, and the JSON routes under `/v1/ai/local/` plus `PUT /v1/ai/analyses/{id}/messages/{messageId}/result`; see section 33.8.

Error codes: `AI_DISABLED` (503, feature not configured on the server), `AI_NOT_CONFIGURED`, `AI_CONSENT_REQUIRED`, `AI_DATA_CHANGED`, `AI_STREAM_IN_PROGRESS`, `AI_PROMPT_TOO_LARGE`, `AI_FOLLOWUP_LIMIT`, and the provider failures `AI_PROVIDER_INVALID_KEY`, `AI_PROVIDER_RATE_LIMITED`, `AI_PROVIDER_QUOTA_EXCEEDED`, `AI_PROVIDER_CONTEXT_TOO_LONG`, `AI_PROVIDER_MODEL_NOT_FOUND`, `AI_PROVIDER_UNAVAILABLE`, `AI_PROVIDER_TIMEOUT`.

### 32.5 Providers and outbound requests

- Native adapters for Anthropic (Messages API), OpenAI (Chat Completions) and Google Gemini (`streamGenerateContent`), plus "OpenAI-compatible" with a user-supplied base URL, which covers Mistral, Groq, DeepSeek, OpenRouter and local servers such as Ollama.
- One interface: `Stream(ctx, request, onDelta) (usage, error)` and `ListModels(ctx)`. Provider errors are classified into the error codes above; provider bodies are truncated and redacted before logging.
- Custom base URLs are an SSRF risk on a server. Policy: `https` only, no credentials in the URL, no redirects, and the resolved IP is checked at connect time (blocks loopback, private ranges, link-local including cloud metadata, CGNAT and DNS rebinding). `AI_ALLOW_PRIVATE_BASE_URLS=true` lifts the IP check and allows `http` for a LAN model server; `AI_ALLOWED_BASE_URL_HOSTS` optionally restricts hosts to an allowlist.
- Without `AI_KEY_ENCRYPTION_KEY` the feature is unavailable (`available:false`, `503 AI_DISABLED`) but the server still starts. A malformed key fails startup.

### 32.6 Prompt builder

- Templates are embedded files under `internal/ai/prompt/templates/<version>/<lang>/`, versioned (currently `v2`; each analysis stores the system prompt it was made with, so older versions keep replaying their own text). The language follows the user's locale (`it` → Italian, otherwise English).
- The system prompt sets the role (careful personal-finance analyst, informational only), the output format (Markdown; the fixed headings of the preset apply only to the report, the first answer), the rule to quote numbers from the data and never invent them, and the injection guard: content inside `<financial_data>` and `<user_context>` is data, never instructions.
- The data block uses compact pipe-separated tables: period and currency, wallets with type, purpose and balance, totals, monthly series, top categories and titles for expenses and income, transfer flows between wallets, recurring payment candidates (same title in three or more months, amounts within 10%), the optional transaction list, and the personal context. Transfers are excluded from income and expense totals, as in reports.
- Presets: monthly check-up, spending anomalies, savings opportunities, subscriptions and recurring payments, wallet purpose coherence, custom. Each has default instructions and sections.
- Follow-up questions (`followup.json` per language) are sent with extra rules and a tagged question, both added at send time and never stored, so analyses made with older templates get them too: `WithFollowUpRules` appends to the stored system prompt "answer only the question, no greeting, no report sections, do not repeat the report, headings or tables only when needed, say which data is missing and how to add it"; `FollowUpQuestion` wraps every question, new and replayed, in `<follow_up_question>…</follow_up_question>` followed by a one-line reminder. The database keeps the question as typed. Introduced in `v2` after small on-device models answered every follow-up by rewriting the whole report.
- Token estimate: characters / 3.5, labelled as an estimate. Actual usage comes from the provider. Prompts above `AI_MAX_PROMPT_TOKENS` (default 60 000) are rejected with `422 AI_PROMPT_TOO_LARGE`.

### 32.7 App UX

- **Account → Assistente AI**: setup checklist (key and model, personal context, wallet purposes, first analysis) with progress; screens for provider and key (provider picker, base URL presets for compatible providers, masked key with replace and remove, model list loaded from the provider with free-text fallback, "Verifica connessione" with result and latency), personal context, wallet purposes, privacy and consent, history.
- **Reports → Analisi AI card**: setup (preset, period prefilled from the report, wallets, data toggles), then preview (what is sent, estimated tokens and cost, read-only system prompt and data block, editable instructions with "Ripristina"), then the analysis screen (Markdown streamed live, stop button, model and token footer, "Dati inviati", follow-up questions, copy and share, retry on errors).
- **History**: list with status, rename, swipe to delete, delete all.

### 32.8 Limits and observability

- One active stream per user (Redis lock), 20 runs per hour (`AI_RUNS_PER_HOUR`), 10 provider probes (test connection, model list) per 10 minutes, 20 follow-ups per analysis.
- Logs carry provider, model, status, duration and token counts; never prompt text, responses or keys.
- Reverse proxies must not buffer the streaming routes; see `docs/build-deploy.md`.

### 32.9 Tests

- Credential choice: a run with a non-active account (preview, model sent, stored provider), follow-ups on the same account, fallback after its removal, refused ids including another user's.

- Provider adapters against scripted `httptest` servers: deltas, usage, end of stream, cancellation, error classification, model list parsing.
- SSRF policy table, secretbox round trip, tampering and key rotation.
- Prompt golden files per preset and language, plus the follow-up rules and wrapped question (`follow_up_<lang>.golden`); totals in the data block match the reports endpoints.
- Integration tests with a scripted provider: follow-up requests carry the follow-up rules and wrapped questions while the stored question stays raw, also for an analysis stored with a v1 prompt and no `options.lang`; event order, saved content equals the streamed text, disconnect → `CANCELLED`, fingerprint mismatch → 409, concurrent stream → 409, streams outlive the normal request timeout, the key never appears in any response.
- Flutter: SSE decoder with chunk boundaries splitting lines and UTF-8 characters, controllers with fake repositories, widget tests for the preview and the consent sheet.

## 33. On-device AI analysis (Analisi AI sul dispositivo)

The AI analysis of section 32 can also run its model **on the user's phone**. The server still builds the prompt from the database and keeps the history; only the text generation moves to the device, so no third party ever sees the data. Android only for now (arm64); iOS builds but reports the feature as unavailable, and the web dashboard (Angular, section 9.9) offers cloud providers only. Measurements behind every choice below are in `docs/ai-on-device-spike.md` (prototype on a Galaxy S26 Ultra, two rounds).

### 33.1 Goals and non-goals

Goals:

- privacy: no provider, no API key, nothing leaves the user's own server and phone;
- the user picks the model and its quantization, from a curated catalog or from any compatible file;
- the same flow and history as cloud analyses: setup → preview → report → follow-ups, stored server-side and visible on every device;
- honest expectations before running: how much of the model's context the prompt takes and how long it should last.

Non-goals:

- no model bundled in the app: models are downloaded (2.4–3.4 GB) or imported after installation;
- no GPU path for llama.cpp: its Vulkan backend crashed on the reference Adreno GPU and is excluded from the build;
- no iOS engine yet.

### 33.2 Architecture

```
app: setup ──preview(target=on_device, profile, budget, device)──▶ server builds prompt, fingerprint
app: load model, count tokens exactly (while the user reads the preview)
app: ──POST /v1/ai/local/analyses (fingerprint, runtime)──▶ server stores analysis + STREAMING report,
                                                          returns system prompt, messages, deadline
app: engine generates on the phone, text streamed into the screen
app: ──PUT …/messages/{id}/result──▶ server stores the report (or the app keeps it in its outbox)
follow-up: ──POST /v1/ai/local/analyses/{id}/messages──▶ server stores the question, returns the
           stored conversation to replay; the phone answers and submits like a report
```

The data block is always rebuilt by the server from the database, exactly as for a cloud run; the phone can only edit the instructions. The conversation controller does not know where text comes from: `AiTurnSource` is implemented both by the repository (cloud SSE) and by `LocalAiRunner` (phone), which emits the same `meta` / `delta` / `usage` / `error` / `done` events.

### 33.3 Engines

Both engines are reached through one package, `flutter_edge_ai` 2.5.0, with `flutter_edge_ai_litertlm` 1.16.0 and `flutter_edge_ai_llama` 0.0.2 (llamadart 0.15.0), behind `LocalLlmEngine` (`lib/features/ai/domain/local/local_llm_engine.dart`; implementation `EdgeAiEngine`).

| Engine | Files | Backends | Notes |
|---|---|---|---|
| LiteRT-LM | `.litertlm` bundles prepared by Google | GPU (default), CPU | GPU activations forced to **float32**: the float16 default writes wrong digits from about 3k prompt tokens (LiteRT-LM issues #2814/#3012). On the CPU the context is capped at 8k (16k is killed for memory). |
| llama.cpp | any GGUF, any quantization | CPU | 4–5× slower to read the prompt than LiteRT-LM on the GPU. Vulkan excluded (`hooks.user_defines.llamadart`: `llama_cpp` runtime, `cpu` backend only). |

- Initialization once per process, `backendFallback: false`: a GPU failure is an error, not a silent switch to the CPU. The backend actually used is recorded in the runtime.
- The package joins all message chunks into one user turn, so earlier turns are flattened into a tagged transcript (`chatTranscript`). Local turns carry each message's `kind`, and the parts are tagged by it: `<initial_request_and_data>`, `<report_already_written>`, `<previous_question>`, `<previous_answer>`; the new question, already wrapped in `<follow_up_question>` by the server (section 32.6), comes last and untagged. Without kinds (older servers) the tags are `<previous_turn role="…">`. Telling the parts apart matters: with everything looking alike, small models took the original report request as the task and rewrote the report for every question.
- Exact token counts come from the engine's tokenizer (`sizeInTokens`). Real tokens are 1.56–1.75× the server's estimate (characters / 3.5), hence each model's `token_factor`.
- Errors map to `AI_LOCAL_OUT_OF_MEMORY`, `AI_LOCAL_CONTEXT_TOO_LONG`, `AI_LOCAL_ENGINE_ERROR`.
- The screen stays on while generating (`wakelock_plus`).

**Model host** (`EngineModelHost`): one model loaded at a time; reloaded when the model, context or backend changes, reused when only the output limit or temperature does; unloaded after 5 minutes idle (never while generating), on memory pressure, when the model is deleted, and on request. It refuses to load when the phone is thermally SEVERE or worse (`AI_LOCAL_TOO_HOT`). Runtime parameters (`paramsFor`): backend from the model's list (default the first), context clamped to 2048..max (CPU max for LiteRT-LM), output 256..context/2 (default 1024), temperature 0..1 (default 0.2).

### 33.4 Catalog

`assets/ai/local_models.json` (`schema_version` 1, `catalog_version` 1). Every entry is pinned to a Hugging Face commit (40-hex revision in the URL) with its SHA-256 and size, and carries RAM thresholds, default and maximum context (and CPU maximum), backends, GPU activation type, `token_factor`, indicative speeds per backend, it/en notes and the license.

| Id | Model | Engine · quantization | Size | Context | Backends | Speed (read/write t/s) |
|---|---|---|---|---|---|---|
| `gemma4-e2b-litert` (recommended) | Gemma 4 E2B | LiteRT-LM · int4/int8 | 2.41 GiB | 16k (CPU 8k) | GPU, CPU | GPU 600/30, CPU 200/23 |
| `gemma4-e4b-litert` | Gemma 4 E4B | LiteRT-LM · int4/int8 | 3.41 GiB | 16k | GPU | 350/14 |
| `qwen35-4b-q4km-gguf` | Qwen3.5 4B | llama.cpp · Q4_K_M | 2.55 GiB | 8k (max 16k) | CPU | 48/10 |
| `gemma4-e2b-q4km-gguf` | Gemma 4 E2B | llama.cpp · Q4_K_M | 2.89 GiB | 8k (max 16k) | CPU | 49/12 |

All four are Apache-2.0 and not gated. RAM fit (`ramFitForSpec`): at or above the recommended RAM "fits", at or above the minimum "tight", otherwise "insufficient" (thresholds in MiB, slightly below nominal RAM because phones report less). Files outside the catalog are estimated with `file + context × 256 KB + 400 MB` against 50% / 70% of the RAM.

### 33.5 Download and import

- **Store** (`ModelStore`): `<app support>/ai_models/<id>/`, excluded from Android backups (`res/xml/backup_rules.xml`, `data_extraction_rules.xml`). `registry.json` (written atomically, writes serialized) holds the installed models, the active model, per-model runtime choices, measured speeds (moving average 0.7/0.3) and the Wi-Fi rule. Models belong to the phone, not to the account.
- **Downloader** (`ModelDownloader`, its own Dio without the app's session headers):
  - resumable: `.part` file plus a `.part.json` validator (ETag, size), `Range` + `If-Range`;
  - redirects followed by hand (max 8), checking Hugging Face's `X-Linked-ETag` and `X-Linked-Size`;
  - 206 continues, 200 restarts from zero, 416 reads the total from `Content-Range: */N` and goes to verification, an inconsistent 206 restarts once;
  - 401/403 → `AI_LOCAL_DOWNLOAD_GATED`, 404 → `…_NOT_FOUND`, other statuses → `…_HTTP`, network errors → `…_NETWORK`;
  - free space checked first with a 512 MB margin (`…_NO_SPACE`);
  - SHA-256 in an isolate, 4 MB chunks; a mismatch deletes the file (`…_CHECKSUM`);
  - optional Hugging Face token (Keystore, `flutter_secure_storage`) sent only to `huggingface.co`;
  - only `https` URLs (`…_INSECURE_URL`).
- **Queue** (`LocalModelsController`): one download at a time; states queued, downloading, paused, waiting for Wi-Fi, verifying, failed. With "Wi-Fi only" (default on) a download waits off Wi-Fi and resumes by itself; partial files found at start show as paused. The first installed model becomes the active one.
- **Import from file** (`file_picker` 13.1.0): Android copies the picked file into the app cache first, then it is copied into the store, its header checked (`GGUF` or `LITERTLM` magic, otherwise `AI_LOCAL_IMPORT_UNKNOWN_FORMAT`) and hashed; the cache copy is cleared afterwards. Name and quantization are guessed from the file name. Without an expected SHA-256 the model is installed as **not verified**. Engine and backends follow the header (LiteRT-LM: GPU then CPU; GGUF: CPU).
- **Import from URL**: an https URL outside the catalog goes through the same queue and checks, optional SHA-256.
- **Device capabilities**: `MethodChannel financialmanager/device` (`MainActivity.kt`) returns total and available RAM, low-memory flag, free storage, thermal status, battery and charging, SoC and SDK.

### 33.6 Compact profile and token budget

Useful for cloud runs too, on by default on the phone.

- `options.profile`: `standard` (default) or `compact`. Compact uses `system_compact.tmpl` (shorter rules, a word limit, a stronger "only use numbers present in the data" rule) and caps the data block (`prompt.LimitsFor`):

| Part | standard | compact |
|---|---|---|
| rows per category list | collected (25) | 8 |
| rows per title list | collected (25) | 10 |
| months | all | last 12, older ones summed in one row |
| recurring candidates | collected (20) | 8 |
| transfer flows | collected (20) | 5 |
| transactions | up to 500 (default 200) | up to 100 (default 60) |
| text in tables | full | titles/categories/wallets 40 chars, purposes 80, each context field 300 |

- `options.budget_tokens` (0, or 1 000..32 000, in the server's estimated tokens): when set, the server gives up detail one step at a time until the prompt fits: `transactions_30`, `transactions_0`, `credit_titles`, `groups_5`, `months_6`, `transfers`, `recurring_4`, `context_150`; still too large → `422 AI_PROMPT_TOO_LARGE`. Deterministic, so a run rebuilds exactly its preview's fingerprint. The steps applied are returned in `disclosure.compaction_steps`.
- The app sets the budget to `(context − max output − 256) / token_factor` (generic factor 1.75 for imports).
- `prompt.Version` stays `v1`: the standard output is byte for byte unchanged.

### 33.7 Data model

Migration `0034_ai_on_device`:

- `ai_settings`: `mode` (`cloud` / `on_device`, CHECK), `local_model` (label of the phone's active model, informational, max 200), `local_consent_version` and `local_consent_accepted_at` (both set or both NULL).
- `ai_analyses`: `runtime JSONB` (engine, model id, display name, quantization, backend, context, max output, app version; NULL for cloud) and a provider CHECK that includes `on_device`. On-device analyses store `provider = on_device` and `model = "<name> · <quantization> · <engine>"`.
- `ai_messages.duration_ms`: how long the phone took.

### 33.8 API

All routes require authentication and keep the normal request timeout (no streaming: the phone streams to itself).

| Method and path | Purpose |
|---|---|
| `PUT /v1/ai/mode` | `{mode, local_model?, version}`; no cloud credential needed; optimistic lock on `version` |
| `PUT` / `DELETE /v1/ai/consent` | gain `scope` (`cloud` default, `on_device`); the on-device disclosure has its own version (`ai.LocalConsentVersion`, 1) |
| `POST /v1/ai/analyses/preview` | gains `target` (`cloud` / `on_device`, empty = saved mode) and `device {context_tokens, max_output_tokens}`; on device returns provider `on_device`, no cost, `context_fit` and `disclosure.profile` / `compaction_steps` |
| `POST /v1/ai/local/analyses` | run request + `runtime`; checks local consent, fingerprint (`409 AI_DATA_CHANGED`), rate limit, runtime bounds and that estimate + output fit the context (`422 AI_LOCAL_CONTEXT_TOO_LONG`); stores the analysis and returns `{analysis_id, message_id, kind, system_prompt, messages, max_output_tokens, deadline_at}`. Idempotent on `client_request_id` while the report is still `STREAMING` (a crashed phone resumes). No Redis lock. |
| `POST /v1/ai/local/analyses/{id}/messages` | follow-up on an on-device analysis: stores the question and returns the replayed history plus the question (wrapped as in the cloud), the system prompt with the follow-up rules (section 32.6), and `question_id` |
| `PUT /v1/ai/analyses/{id}/messages/{messageId}/result` | `{content, status, error_code, input_tokens, output_tokens, truncated, duration_ms}`; body up to 512 KB, content up to 200 KB (`422 AI_ANSWER_TOO_LONG`); the same submission again is accepted (outbox retries), a different one for a saved message is `409 AI_MESSAGE_FINISHED`; `error_code` limited to the `AI_LOCAL_*` list, anything else stored as `AI_LOCAL_ENGINE_ERROR` |

`GET /v1/ai/settings` returns `on_device_available`, `mode`, `local_model` and `consent.on_device`; it no longer answers `available: false` early when only the on-device path is enabled. History and detail responses carry `runtime` and per-message `duration_ms`.

Availability is split: `requireFeature` (cloud **or** on-device enabled) guards history, context, presets, consent and preview; the cloud requirements (`AI_KEY_ENCRYPTION_KEY`, an active credential) guard only keys, tests, model lists and cloud runs. Changes to the existing code: `effectiveStatus` uses `AI_LOCAL_MAX_DURATION` for on-device rows instead of the cloud stream window; a cloud follow-up on an on-device analysis answers `409 AI_ANALYSIS_ON_DEVICE` (and a local follow-up or result on a cloud one `409 AI_ANALYSIS_NOT_ON_DEVICE`); cost is `null` for on-device analyses.

Configuration: `AI_ON_DEVICE_ENABLED` (default `true`; works without `AI_KEY_ENCRYPTION_KEY`), `AI_LOCAL_RUNS_PER_HOUR` (30, reports and follow-ups together), `AI_LOCAL_MAX_DURATION` (30m: the deadline given to the phone and after which a pending message shows as interrupted). Follow-ups are capped at 20 per analysis, as in the cloud.

Error codes: `AI_ON_DEVICE_DISABLED` (503), `AI_LOCAL_CONSENT_REQUIRED` (403), `AI_ANALYSIS_ON_DEVICE`, `AI_ANALYSIS_NOT_ON_DEVICE`, `AI_MESSAGE_FINISHED` (409), `AI_LOCAL_CONTEXT_TOO_LONG`, `AI_ANSWER_TOO_LONG` (422). Codes reported by the phone: `AI_LOCAL_ENGINE_ERROR`, `AI_LOCAL_OUT_OF_MEMORY`, `AI_LOCAL_CONTEXT_TOO_LONG`, `AI_LOCAL_TIMEOUT`, `AI_LOCAL_MODEL_MISSING`, `AI_LOCAL_INTERRUPTED`. App-only codes: `AI_LOCAL_UNSUPPORTED`, `AI_LOCAL_TOO_HOT`, `AI_LOCAL_DOWNLOAD_NETWORK`, `…_GATED`, `…_NOT_FOUND`, `…_HTTP`, `…_NO_SPACE`, `…_CHECKSUM`, `…_INSECURE_URL`, `AI_LOCAL_IMPORT_UNKNOWN_FORMAT`.

### 33.9 Running on the phone

`LocalAiRunner` (`lib/features/ai/data/local/local_ai_runner.dart`), held by a provider that outlives the screens:

1. flushes the outbox (best effort) and acquires the engine;
2. prepares the turn on the server;
3. trims follow-up history to the context: the oldest question/answer pairs go first, the data message and the report never;
4. streams deltas to the screen; answers are capped at 200 KB (truncated);
5. Stop or leaving the screen cancels the engine and the partial text is kept as `CANCELLED`; the deadline (`deadline_at` minus 2 minutes) stops it as `AI_LOCAL_TIMEOUT`;
6. submits the result; if the network fails the result goes to the **outbox** (`<app support>/ai_local/outbox.json`), sent again before each run, at sign-in and whenever the app returns to the foreground;
7. records the measured speed for later estimates.

**Outbox rules.** Each item records its account, the author's name, the model and whether it is a report or an answer. Items never expire and survive a sign-out: they stay until the server accepts them or their author deletes them.

- Only the author's session sends an item, automatically or with "Invia ora"; signing in again with the same account sends what is waiting.
- A result the server refuses for good (the analysis was deleted meanwhile, the answer was saved differently) stays, marked with the server's error code, and is no longer retried by itself: its author resends or deletes it.
- **Anyone using the app on the phone can read the items** in Cronologia → "Risposte non inviate" (a banner shows while any exist); only the author can send or delete them.

**Background work** (Android): downloads and generation run in the main Dart isolate, kept alive by a foreground service (`flutter_foreground_task`, types `dataSync` and `specialUse`, wake lock and Wi-Fi lock).

- `BackgroundWork` starts the service with the first job and stops it with the last; its notification lists the jobs ("Download Gemma 4 E2B · 45%", "Scrittura del report · 230 parole") with **Pausa** for downloads and **Interrompi** for analyses.
- The service's own isolate only relays button presses and a system timeout to the main isolate.
- The Flutter engine starts in `FinancialManagerApplication` and lives in `FlutterEngineCache`, so the work survives the user swiping the app from the recents; reopening attaches to the same engine.
- **Downloads:** the service also stays up while a download waits for Wi-Fi, since Android doesn't let an app start a foreground service from the background; that way the download resumes by itself. Pausa and the Android 15+ `dataSync` limit (6 hours a day, reset when the app comes to the foreground) pause the downloads.
- **Generation:** a turn runs to its end whether or not a screen listens; only Stop, Interrompi or the deadline stop it. Leaving an analysis while the phone writes asks: **Interrompi** (partial text saved), **Resta**, or **Continua in background** (the conversation controller is kept alive until the turn ends). A screen opened meanwhile, from the history or a notification, follows the live text (`LocalAiRunner.live`) and then reloads the stored analysis.
- **Notifications** (`flutter_local_notifications`, channel "Analisi AI"): "Analisi pronta" / "Risposta pronta" with the analysis title, or "Analisi interrotta" with the reason. They show when the app is off screen or on another screen, never when the user stopped the run or with the AI features off. Downloads notify "Modello pronto" / "Download non riuscito" when the app is off screen. A tap opens the analysis or the models screen once the session is authenticated. Notifications carry titles and model names, never content. The notification permission is asked the first time work starts; refused, everything works with a hidden notification.

**Follow-ups on the phone** continue with the report's model when it is still installed (`acquire(modelId:)`), otherwise with the active model, and the question bar says which model will answer. On a device that can't run them (iOS, no engines, no model installed) the bar is disabled with an explanation instead of failing after sending.

**Time estimate** shown in the preview, ±30%: `load (5 s LiteRT-LM, 8 s llama.cpp, 0 if loaded) + input tokens / reading speed + min(max output, 900) / writing speed`. Speeds come from the phone's own measurements, else the catalog, else 50/8 tokens/s. "Misura velocità" runs about 1 000 tokens in and 128 out with the active model and records the result like a real run.

**Context use** is computed by the app in real tokens (exact once the engine counted the prompt, otherwise the server estimate × `token_factor`), plus the reserved output and 256 tokens of template: green, amber above 85%, red when it doesn't fit. The server's own `context_fit` counts estimated tokens and is not used for the bar.

**Warnings**: thermal MODERATE ("the phone is warm"), battery below 15% and not charging, Android low-memory flag. SEVERE refuses the run.

### 33.10 App UX

- **Fornitore e chiave API**: a Cloud / Sul dispositivo switch when the server offers on-device runs (saves the mode and the active model's label). On device: active model, runtime settings, on-device disclosure with revoke; on a phone without engines, a notice.
- **Modelli sul dispositivo** (`/app/account/ai/local-models`): RAM and free space, "Solo Wi-Fi"; installed models (use, delete with space freed; "non verificato" badge); the catalog by engine with "Consigliato", RAM fit, size, context, backends and license; download / pause / resume / retry / cancel with progress; a license dialog before every download and, for gated repositories, the model page and token; import from file or URL; Hugging Face token. The server-side label follows whatever makes a model active.
- **Impostazioni di esecuzione** (`/app/account/ai/local-runtime`): backend, context (memory warning above the model's default), answer length, temperature, reset; "Misura velocità" with the speed's source.
- **Setup**: on device the compact profile is on by default (60 transactions, at most 100); the request carries target, budget and device limits; the on-device disclosure is asked instead of the cloud one; no model installed or an unsupported phone shows what to do.
- **Preview**: "processed on the phone with …", no cost, compaction note, context bar with time estimate and warnings; the model loads while the user reads and the estimate becomes an exact count; quick fixes when tight or full (compact profile, fewer transactions, shorter answer, larger context); a prompt that doesn't fit cannot be run.
- **Analysis**: header "Sul dispositivo · model · quantization · backend · tokens/s · duration"; while the phone writes, a banner says the user may leave the app and will be notified, and Back asks whether to stop, stay or continue in the background.
- **History**: a phone icon on on-device analyses; a banner leads to **Risposte non inviate** (`/app/ai/pending`), where results waiting on the phone are listed with author, date, model and status, readable by anyone and sent or deleted by their author.
- **Follow-ups on a phone analysis**: disabled with an explanation where the phone can't answer; a note when a different model than the report's will answer. **Assistant hub**: on device the checklist's first step is an installed model plus the on-device disclosure.
- **Disclosure** (on-device scope): where the data is processed (the phone, no outside provider), what the server keeps (the data summary and the history), the model can be wrong, models come from Hugging Face with their own license, how to revoke.

### 33.11 Android build

- `minSdk` 30 (`maxOf(flutter.minSdkVersion, 30)`); iOS deployment target 15.0 (required by `flutter_edge_ai`).
- Release APKs ship `arm64-v8a` only (`androidComponents` packaging excludes for `armeabi-v7a`, `x86`, `x86_64`): about 92 MB. Debug builds keep every ABI.
- R8 keep rules for `io.flutter.plugins.sharedpreferences.**` and the `jni` / `jni_flutter` bridges (`proguard-rules.pro`), after a JNI method stripped by R8 crashed the prototype.
- CI builds the arm64 release with `--analyze-size`.
- Background work: permissions `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_DATA_SYNC`, `FOREGROUND_SERVICE_SPECIAL_USE`, `POST_NOTIFICATIONS`, `WAKE_LOCK`; `flutter_foreground_task`'s service declared with `foregroundServiceType="dataSync|specialUse"`, `stopWithTask="false"` and the `PROPERTY_SPECIAL_USE_FGS_SUBTYPE` explanation (a Play Store release must justify `specialUse`). `FinancialManagerApplication` owns the cached engine. Core library desugaring (`desugar_jdk_libs` 2.1.5) for `flutter_local_notifications`.

### 33.12 Limits and known gaps

- Background work ends if the system kills the process anyway (extreme memory pressure, a force stop): downloads resume from their partial file, an interrupted turn shows as interrupted after its window.
- Downloads in the background are bound by Android 15+'s 6-hour daily `dataSync` limit.
- Whether LiteRT-LM's GPU path keeps full speed with the screen off is to be measured on each phone.
- Small models can mix up numbers: the disclosure says so and the compact prompt insists on quoting only the data. In the prototype no model found a deliberately duplicated charge.
- Thread count and GPU layers from the original plan are not offered: `flutter_edge_ai` exposes neither, and llama.cpp runs on the CPU only.
- The setup checklist counts an imported, not verified model as installed.
- Picking a file temporarily needs twice its size (the picker's cache copy).
- No iOS engine; NPU bundles (SoC-specific) are not in the catalog.

### 33.13 Tests

- Backend (`internal/ai/local_integration_test.go`, harness without the secretbox): full path without a cloud credential, missing local consent → 403, fingerprint mismatch → 409, prepare idempotency, result over 200 KB → 422, result sent twice (same → 200, different → 409), result on a cloud analysis → 409, local follow-ups (wrapped question, follow-up system prompt, message kinds) and their limit, cloud follow-up on a local analysis → 409, expiry window with a fake clock, rate limit, mode version conflict, unknown error codes normalized. Compact golden files it/en, collector limits, budget determinism, preview/run fingerprint equality.
- App, with fake engines and servers: runner (event order, submitted content, stop, out of memory, context too long, outbox, history trimming keeping message kinds), transcript tagging by kind with the role-only fallback, turn routing, downloader (resume, restart, 416, changed ETag, wrong checksum, Wi-Fi lost, no space, gated), store, catalog validation (unique ids, pinned URLs and SHA-256, engine/format coherence, RAM and context bounds, licenses, notes in both languages), model host (params, reloads, idle unload, thermal refusal, speeds, benchmark), run plan (budget, context levels, estimate, speed sources), outbox flush on sign-in and resume, outbox rules (no expiry, refused items kept and not retried, send and delete by the author only), follow-ups asking for the report's model and the host's fallback to the active model, the last model picked (first while available, per account), background work (the download line over the queue, the service kept while waiting for Wi-Fi, Pausa and timeouts, a turn going on without listeners, Interrompi, end-of-run and end-of-download notifications only when the user isn't looking); widget tests for the preview's context states and quick fixes, the models screen (progress, pause, failure, license, gated token), the on-device disclosure, the mode switch, the unsent results screen (readable by anyone, actions for the author only), a screen following a live turn and the leave dialog.
- Manual protocol on the S26 Ultra: download with Wi-Fi lost and resumed, corrupted file, GGUF import, benchmark, standard and compact check-ups on CPU and GPU, follow-ups, stop, app killed mid-run, airplane mode after prepare, heat after repeated runs, model deletion, history on a second device. First field result: a full report on three months and 150 transactions in 40–60 s with Gemma 4 E2B on the GPU.

### 32.10 AI features switch

**Account → Preferenze → Funzioni AI** turns every AI entry point off for the account: the Assistente AI menu, the Analisi AI card in Reports, the "analyze with AI" action in Cronologia, the wallet purpose field, and the `/app/ai/…` and `/app/account/ai/…` routes (a stale link lands on Account). Turning it off deletes nothing: analyses, keys, personal context, wallet purposes and models on the phone stay as they are and come back when it is turned on.

- Stored as `users.ai_enabled` (migration `0035_ai_choice_and_switch`, default `true`, so existing accounts keep what they had), returned by `GET /v1/me` and accepted by `PATCH /v1/me`, where an omitted value keeps the stored one (older apps don't send it).
- It only drives what the app shows; the AI routes don't check it.
- Until the profile has loaded the app treats the features as off, so they never flash in for a user who turned them off.

---

# Summary of recommended decisions

To start development without ambiguity, the recommended baseline is:

- Feature-first Flutter with MVVM, repositories, and use cases.
- Go backend as a modular monolith.
- PostgreSQL as the single source of financial data.
- Redis for cache, rate limiting, and temporary tickets.
- Amounts in `BIGINT` cents.
- Balance updated only through atomic database transactions.
- Adjustment instead of manual balance overwrite.
- Single wallet in the MVP, schema ready for multiple wallets.
- Reusable titles via templates.
- Categories added for readable reports.
- Reports by title/template and category, with income and expenses separated.
- Images in private object storage, metadata in PostgreSQL.
- Client-side 1:1 crop with server-side validation and re-encoding.
- Google as an identity linked to the application account, not as an alternative incomplete profile.
- API documented in OpenAPI.
- Docker Compose with host ports `10001`, `10002`, `10003`, `10004` in development; database, Redis, and object storage not public in production.
- Online-only MVP for writes, with local cache for recent reads.

This plan is a sufficient basis for moving to the next phase: detailed wireframes, a navigable prototype, and the final visual definition of every screen.
