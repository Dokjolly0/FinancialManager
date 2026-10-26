// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'FinancialManager';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get errorGenericTitle => 'Something went wrong';

  @override
  String get errorNetworkTitle => 'No connection';

  @override
  String get errorSessionExpiredTitle => 'Session expired';

  @override
  String get emptyStateDefaultMessage => 'Nothing to show.';

  @override
  String get errorCodeNetworkError =>
      'No connection. Check your network and try again.';

  @override
  String get errorCodeSessionExpired =>
      'Your session has expired. Please sign in again.';

  @override
  String get errorCodeRateLimitedGeneric =>
      'Too many attempts. Try again later.';

  @override
  String errorCodeRateLimitedWithSeconds(int seconds) {
    return 'Too many attempts. Try again in $seconds seconds.';
  }

  @override
  String get errorCodeUnknownError => 'Something went wrong. Please try again.';

  @override
  String get errorCodeWalletNotFound => 'Wallet not found.';

  @override
  String get errorCodeAiDisabled =>
      'AI analysis is not enabled on this server.';

  @override
  String get errorCodeAiNotConfigured =>
      'Set up a provider, an API key and a model first.';

  @override
  String get errorCodeAiConsentRequired =>
      'Accept the AI analysis notice to continue.';

  @override
  String get errorCodeAiDataChanged =>
      'Your data changed after the preview: check it again.';

  @override
  String get errorCodeAiStreamInProgress =>
      'Another analysis is in progress: wait for it or stop it.';

  @override
  String get errorCodeAiPromptTooLarge =>
      'Too much data for one analysis: choose a shorter period, fewer wallets or fewer transactions.';

  @override
  String get errorCodeAiFollowupLimit =>
      'You reached the maximum number of questions for this analysis: start a new one.';

  @override
  String get errorCodeAiAnalysisExists =>
      'This analysis was already started: find it in the history.';

  @override
  String get errorCodeAiAnalysisNotReady =>
      'Follow-up questions need a completed report.';

  @override
  String get errorCodeAiKeyUnreadable =>
      'The saved API key can no longer be read: enter it again.';

  @override
  String get errorCodeAiStreamInterrupted =>
      'The analysis stopped before finishing.';

  @override
  String get errorCodeAiAnswerTooLong =>
      'The answer was too long and was cut short.';

  @override
  String get errorCodeAiProviderError => 'The AI provider returned an error.';

  @override
  String get errorCodeAiProviderInvalidKey =>
      'The API key is invalid or lacks the required permissions.';

  @override
  String get errorCodeAiProviderRateLimited =>
      'The AI provider is limiting requests: try again shortly.';

  @override
  String get errorCodeAiProviderQuotaExceeded =>
      'Your AI provider credit or quota is used up: check your account with the provider.';

  @override
  String get errorCodeAiProviderContextTooLong =>
      'The model cannot read this much data: shorten the period or include fewer transactions.';

  @override
  String get errorCodeAiProviderModelNotFound =>
      'The chosen model does not exist or is not available to your key.';

  @override
  String get errorCodeAiProviderContentBlocked =>
      'The AI provider blocked the answer with its safety filters.';

  @override
  String get errorCodeAiProviderUnavailable =>
      'The AI provider is temporarily overloaded or unavailable.';

  @override
  String get errorCodeAiProviderTimeout =>
      'The AI provider took too long and the analysis was stopped.';

  @override
  String get errorCodeAiProviderUnreachable =>
      'The AI provider could not be reached.';

  @override
  String get errorCodeAiProviderInvalid => 'Unsupported provider.';

  @override
  String get errorCodeAiBaseUrlInvalid =>
      'Enter a valid https address, without credentials or parameters.';

  @override
  String get errorCodeAiBaseUrlNotAllowed =>
      'This server cannot connect to private or local addresses.';

  @override
  String get errorCodeAiTextTooLong => 'The text is too long.';

  @override
  String get errorCodeValueOutOfRange => 'Value out of the allowed range.';

  @override
  String get errorCodeInvalidValue => 'Invalid value.';

  @override
  String get errorCodeAiConsentVersionInvalid =>
      'The notice was updated: read and accept it again.';

  @override
  String get errorCodeValidationError => 'Check the highlighted fields.';

  @override
  String get errorCodeBadRequest => 'Malformed request.';

  @override
  String get errorCodeUnauthorized => 'Authentication required or invalid.';

  @override
  String get errorCodeForbidden => 'This action isn\'t allowed.';

  @override
  String get errorCodeNotFound => 'Resource not found.';

  @override
  String get errorCodeConflict =>
      'This resource has changed since you last loaded it.';

  @override
  String get errorCodeInternalError => 'An internal error occurred.';

  @override
  String get errorCodeEmailInUse => 'Email already registered.';

  @override
  String get errorCodeUsernameInUse => 'Username already in use.';

  @override
  String get errorCodeInvalidCredentials => 'Invalid credentials.';

  @override
  String get errorCodeInvalidCurrentPassword =>
      'Your current password is incorrect.';

  @override
  String get errorCodeInvalidOrExpiredToken =>
      'This link is invalid or has expired.';

  @override
  String get errorCodeInvalidGoogleToken => 'Invalid Google token.';

  @override
  String get errorCodeGoogleAccountAlreadyLinked =>
      'This Google account is already linked to another user.';

  @override
  String get errorCodeNoAlternativeLoginMethod =>
      'Set a password first so you can unlink Google.';

  @override
  String get errorCodeIdempotencyKeyReused =>
      'This request was already submitted with different data.';

  @override
  String get errorCodeAccountDeletionPending =>
      'This account is scheduled for deletion.';

  @override
  String get errorCodeAccountLocked =>
      'This account is temporarily locked. Try again later.';

  @override
  String get errorCodeNoPasswordSet => 'No password is set for this account.';

  @override
  String get errorCodeReauthRequired =>
      'Confirm your password to link a Google account.';

  @override
  String get errorCodeCategoryAlreadyExists =>
      'A category with this name already exists for this direction.';

  @override
  String get errorCodeSystemCategoryNotEditable =>
      'System categories can\'t be edited.';

  @override
  String get errorCodeSystemCategoryNotDeletable =>
      'System categories can\'t be deleted.';

  @override
  String get errorCodeCategoryNotHideable =>
      'Only system categories can be hidden: delete your own instead.';

  @override
  String get errorCodeTemplateAlreadyExists =>
      'A template with this title already exists for this direction.';

  @override
  String get errorCodeExportNotReady => 'The export isn\'t ready yet.';

  @override
  String get errorCodeUploadTooLarge =>
      'The file exceeds the maximum allowed size.';

  @override
  String get errorCodeImageTooLarge =>
      'The image exceeds the maximum allowed dimensions.';

  @override
  String get errorCodeUnsupportedImageFormat =>
      'This image format isn\'t supported. Use JPEG, PNG, or WebP.';

  @override
  String get errorCodeImageFetchFailed =>
      'Couldn\'t download the selected image.';

  @override
  String get errorCodeImageSearchFailed =>
      'Image search is unavailable right now.';

  @override
  String get errorCodeMediaInUse =>
      'This image is still in use and can\'t be deleted.';

  @override
  String get errorCodeNotEditable =>
      'Only standard transactions can be edited.';

  @override
  String get errorCodeOpeningBalanceNotDeletable =>
      'The opening balance can\'t be deleted directly.';

  @override
  String get errorCodeCategoryNotFound => 'Category not found.';

  @override
  String get errorCodeTemplateNotFound => 'Template not found.';

  @override
  String get errorCodeMediaNotFound => 'Image not found.';

  @override
  String get errorCodeWalletNotMealVoucher =>
      'Only available for meal-voucher wallets.';

  @override
  String get errorCodeWalletIsMealVoucher =>
      'Not available for meal-voucher wallets: use the voucher-specific operations.';

  @override
  String get errorCodeVoucherInsufficientBalance =>
      'Not enough vouchers available.';

  @override
  String get errorCodeVoucherLotAlreadyUsed =>
      'Some of these vouchers have already been spent or removed.';

  @override
  String get errorCodeVoucherLotAlreadyExpired =>
      'This voucher lot has already expired and can no longer be edited.';

  @override
  String get errorCodeVoucherAutoAdjustmentNotDeletable =>
      'Automatic voucher expiry adjustments can\'t be deleted.';

  @override
  String get errorCodeOtherWalletRequired =>
      'Select the wallet that paid the difference.';

  @override
  String get errorCodeOtherWalletNotAllowed =>
      'The chosen vouchers already cover the whole expense: no other wallet is needed.';

  @override
  String get errorCodeSameAsVoucherWallet =>
      'The difference wallet must be different from the voucher wallet.';

  @override
  String get errorCodeInvalidMonth => 'Invalid month.';

  @override
  String get errorCodeInvalidDay => 'Invalid day.';

  @override
  String get errorCodeNotAllowedForWalletType =>
      'Not allowed for this wallet type.';

  @override
  String get errorCodePurposeLengthInvalid =>
      'The purpose can be at most 280 characters.';

  @override
  String get errorCodeLinkTargetNotFound =>
      'The transaction to link to was not found.';

  @override
  String get errorCodeLinkTargetNotLinkable =>
      'This transaction can\'t be linked.';

  @override
  String get errorCodeNotInPaymentGroup =>
      'This transaction isn\'t linked to any other.';

  @override
  String get errorCodeRequiredField => 'This field is required.';

  @override
  String get errorCodeUsernameLengthInvalid =>
      'Must be between 3 and 40 characters.';

  @override
  String get errorCodeInvalidEmail => 'Invalid email address.';

  @override
  String get errorCodePasswordTooShort => 'Must be at least 8 characters.';

  @override
  String get errorCodePasswordsDoNotMatch => 'Passwords don\'t match.';

  @override
  String get errorCodeInvalidColorFormat => 'Invalid color format.';

  @override
  String get errorCodeNegativeNotAllowed => 'Can\'t be negative.';

  @override
  String get errorCodeCurrencyNotSupported =>
      'Only EUR is supported in this version.';

  @override
  String get errorCodeTermsNotAccepted =>
      'You must accept the terms to continue.';

  @override
  String get errorCodeInvalidUuid => 'Must be a valid UUID.';

  @override
  String get errorCodeInvalidDirection => 'Must be CREDIT or DEBIT.';

  @override
  String get errorCodeAmountNotPositive => 'Must be greater than zero.';

  @override
  String get errorCodeAmountImplausible => 'This amount doesn\'t look right.';

  @override
  String get errorCodeTitleLengthInvalid =>
      'Must be between 1 and 120 characters.';

  @override
  String get errorCodeCurrencyMismatch => 'Must match the wallet\'s currency.';

  @override
  String get errorCodeMustBeInteger => 'Must be a whole number.';

  @override
  String get errorCodeInvalidRfc3339Date => 'Must be a valid date.';

  @override
  String get errorCodeInvalidCategoryScope => 'Must be DEBIT, CREDIT, or BOTH.';

  @override
  String get errorCodeCategoryNameLengthInvalid =>
      'Must be between 1 and 80 characters.';

  @override
  String get errorCodeInvalidTheme => 'Must be system, light, or dark.';

  @override
  String get errorCodeInvalidFirstDayOfWeek => 'Must be monday or sunday.';

  @override
  String get errorCodeInvalidExportFormat => 'Must be csv or json.';

  @override
  String get errorCodeInvalidTimezone => 'Invalid timezone.';

  @override
  String get errorCodeInvalidPreset => 'Invalid value.';

  @override
  String get errorCodeCustomRangeRequired =>
      '\'from\' and \'to\' are required when preset=custom.';

  @override
  String get errorCodeInvalidGroupBy => 'Must be title or category.';

  @override
  String get errorCodeInvalidMediaKind =>
      'Must be profile, transaction, or category.';

  @override
  String get errorCodeProviderNotSupported => 'This provider isn\'t supported.';

  @override
  String get errorCodeInvalidAmount => 'Invalid amount.';

  @override
  String get errorCodeRegistrationSessionExpired =>
      'Your registration session has expired. Try again with Google.';

  @override
  String get errorCodeExportFailed => 'The export failed. Please try again.';

  @override
  String get commonSave => 'Save';

  @override
  String get commonContinue => 'Continue';

  @override
  String get accountScreenTitle => 'Account';

  @override
  String get accountLogoutConfirmTitle => 'Log out?';

  @override
  String get accountLogoutAction => 'Log out';

  @override
  String get accountLogoutAllConfirmTitle => 'Log out of all devices?';

  @override
  String get accountLogoutAllConfirmMessage =>
      'All active sessions will be ended.';

  @override
  String get accountLogoutAllAction => 'Log out everywhere';

  @override
  String get accountLogoutAllMenuTitle => 'Log out of all devices';

  @override
  String get accountProfileLoadError => 'Couldn\'t load the profile.';

  @override
  String get accountWalletLabel => 'Wallet';

  @override
  String get accountBalanceAdjustmentAction => 'Adjust balance';

  @override
  String get accountWalletsMenuTitle => 'Wallets';

  @override
  String get accountWalletsMenuSubtitle => 'Manage your accounts and cash';

  @override
  String get walletsScreenTitle => 'Wallets';

  @override
  String get walletsTotalBalanceLabel => 'Total balance';

  @override
  String get addWalletAction => 'New wallet';

  @override
  String get walletsLoadError => 'Couldn\'t load your wallets.';

  @override
  String get walletsEmptyStateMessage => 'No active wallets.';

  @override
  String get transferAction => 'Transfer';

  @override
  String get newWalletScreenTitle => 'New wallet';

  @override
  String get editWalletScreenTitle => 'Edit wallet';

  @override
  String get walletNameLabel => 'Name';

  @override
  String get walletPurposeLabel => 'Purpose (optional)';

  @override
  String get walletPurposeHint =>
      'E.g. daily expenses, emergency fund, holiday savings';

  @override
  String get walletPurposeHelper =>
      'Helps AI analysis understand what this wallet is for.';

  @override
  String get walletTypeLabel => 'Type';

  @override
  String get walletTypeCash => 'Cash';

  @override
  String get walletTypeBank => 'Bank account';

  @override
  String get walletTypeOther => 'Other';

  @override
  String get walletIconLabel => 'Icon';

  @override
  String get walletColorLabel => 'Color';

  @override
  String get saveWalletAction => 'Save wallet';

  @override
  String get createWalletError => 'Couldn\'t create the wallet.';

  @override
  String get updateWalletError => 'Couldn\'t save the wallet.';

  @override
  String get archiveWalletAction => 'Archive wallet';

  @override
  String get archiveWalletConfirmTitle => 'Archive this wallet?';

  @override
  String get archiveWalletConfirmMessage =>
      'The wallet will be archived and no longer selectable for new transactions; its history stays in reports.';

  @override
  String archiveWalletConfirmMessageWithBalance(String balance) {
    return 'This wallet still has a balance of $balance. It will be archived and no longer selectable for new transactions; its history stays in reports.';
  }

  @override
  String get archiveWalletError => 'Couldn\'t archive the wallet.';

  @override
  String get walletDenominationsAction => 'Banknotes and coins';

  @override
  String get walletDenominationsScreenTitle => 'Banknotes and coins';

  @override
  String get denominationCountLabel => 'Count';

  @override
  String get saveDenominationsAction => 'Save count';

  @override
  String get denominationsLoadError => 'Couldn\'t load banknotes and coins.';

  @override
  String get walletPickerTitle => 'Choose a wallet';

  @override
  String get selectWalletPlaceholder => 'Select a wallet';

  @override
  String get transferSheetTitle => 'Transfer between wallets';

  @override
  String get transferSourceWalletLabel => 'From';

  @override
  String get transferDestinationWalletLabel => 'To';

  @override
  String get transferAmountLabel => 'Amount';

  @override
  String get transferNoteLabel => 'Note (optional)';

  @override
  String get submitTransferAction => 'Transfer';

  @override
  String get transferSameWalletError =>
      'The destination wallet must be different from the source.';

  @override
  String get editTransferSheetTitle => 'Edit transfer';

  @override
  String get saveTransferAction => 'Save transfer';

  @override
  String get walletBadgeArchived => 'Archived';

  @override
  String get allWalletsLabel => 'All wallets';

  @override
  String get walletTypeMealVoucher => 'Meal vouchers';

  @override
  String get voucherUnitValueLabel => 'Voucher face value';

  @override
  String get voucherExpiryPolicyLabel => 'Voucher expiry';

  @override
  String get voucherExpiryCutoffMonthLabel => 'Through month';

  @override
  String get voucherExpiryMonthLabel => 'Expiry month';

  @override
  String get voucherExpiryDayLabel => 'Expiry day';

  @override
  String get voucherInitialQuantityLabel => 'Initial number of vouchers';

  @override
  String get voucherLoadedAtLabel => 'Load date';

  @override
  String get voucherLotsAction => 'Meal vouchers';

  @override
  String get voucherLotsScreenTitle => 'Meal vouchers';

  @override
  String get voucherLotsLoadError => 'Couldn\'t load meal vouchers.';

  @override
  String get voucherActiveSectionTitle => 'Active';

  @override
  String get voucherActiveEmptyMessage => 'No active vouchers.';

  @override
  String get voucherExpiringSoonSectionTitle => 'Expiring soon';

  @override
  String get voucherExpiredSectionTitle => 'Expired';

  @override
  String get voucherExpiredEmptyMessage => 'No expired vouchers.';

  @override
  String voucherLotQuantityLabel(int count) {
    return '$count vouchers';
  }

  @override
  String voucherLotExpiresOnLabel(String date) {
    return 'Expires on $date';
  }

  @override
  String voucherLotExpiredOnLabel(String date) {
    return 'Expired on $date';
  }

  @override
  String voucherExpiringSoonBadge(int count) {
    return '$count vouchers expiring soon';
  }

  @override
  String get addVouchersAction => 'Add vouchers';

  @override
  String get removeVouchersAction => 'Remove vouchers';

  @override
  String get addVouchersSheetTitle => 'Add vouchers';

  @override
  String get removeVouchersSheetTitle => 'Remove vouchers';

  @override
  String get voucherQuantityLabel => 'Number of vouchers';

  @override
  String get voucherExpenseAction => 'Expense with meal vouchers';

  @override
  String get voucherExpenseSheetTitle => 'Expense with meal vouchers';

  @override
  String get editVoucherExpenseSheetTitle => 'Edit meal voucher expense';

  @override
  String get voucherWalletLabel => 'Voucher wallet';

  @override
  String get voucherOtherWalletLabel => 'Paid with';

  @override
  String get voucherOtherWalletRequiredError =>
      'Select the wallet that paid the difference.';

  @override
  String get voucherTotalExpenseLabel => 'Total expense';

  @override
  String voucherShortfallLabel(String amount) {
    return 'Difference to pay: $amount';
  }

  @override
  String voucherSuggestedQuantityHelper(int count) {
    return 'Suggested minimum: $count';
  }

  @override
  String get submitVoucherExpenseAction => 'Record expense';

  @override
  String get saveVoucherExpenseAction => 'Save expense';

  @override
  String get noImageSelectedLabel => 'No image';

  @override
  String get imageSelectedLabel => 'Image selected';

  @override
  String get accountSecurityMenuTitle => 'Security';

  @override
  String get accountSecurityMenuSubtitle => 'Password, active sessions, logout';

  @override
  String get accountLinkedAccountsMenuTitle => 'Linked accounts';

  @override
  String get accountPreferencesMenuTitle => 'Preferences';

  @override
  String get accountPreferencesMenuSubtitle =>
      'Theme, timezone, language, balance, AI features';

  @override
  String get accountDataMenuTitle => 'Data';

  @override
  String get accountDataMenuSubtitle => 'Export or delete your account';

  @override
  String get accountPreferencesLoadError => 'Couldn\'t load preferences.';

  @override
  String get themeLabel => 'Theme';

  @override
  String get themeOptionSystem => 'System';

  @override
  String get themeOptionLight => 'Light';

  @override
  String get themeOptionDark => 'Dark';

  @override
  String get firstDayOfWeekLabel => 'First day of the week';

  @override
  String get weekdayMonday => 'Monday';

  @override
  String get weekdaySunday => 'Sunday';

  @override
  String get hideBalanceOnOpenTitle => 'Hide balance on open';

  @override
  String get hideBalanceOnOpenSubtitle =>
      'The balance will be hidden by default on Home';

  @override
  String get timezoneLabel => 'Timezone';

  @override
  String get languageLabel => 'Language';

  @override
  String get deleteAccountConfirmTitle => 'Delete account?';

  @override
  String get deleteAccountConfirmMessage =>
      'This action is irreversible. Your profile will be removed; recorded transactions remain for accounting purposes only.';

  @override
  String get confirmPasswordDialogTitle => 'Confirm your password';

  @override
  String get currentPasswordOptionalGoogleLabel =>
      'Current password (empty if Google-only)';

  @override
  String get deleteAccountAction => 'Delete account';

  @override
  String get exportDataSectionTitle => 'Export your data';

  @override
  String get exportDataDescription =>
      'CSV for transactions, JSON for profile, wallet, categories, templates, transactions, and AI analyses.';

  @override
  String get exportCsvAction => 'Export CSV';

  @override
  String get exportJsonAction => 'Export JSON';

  @override
  String get dangerZoneTitle => 'Danger zone';

  @override
  String get accountProfileScreenTitle => 'Profile';

  @override
  String get profileUpdatedMessage => 'Profile updated.';

  @override
  String get verificationEmailSentMessage => 'Verification email sent.';

  @override
  String get firstNameLabel => 'First name';

  @override
  String get lastNameLabel => 'Last name';

  @override
  String get usernameLabel => 'Username';

  @override
  String get emailLabel => 'Email';

  @override
  String get resendVerificationTooltip => 'Resend verification';

  @override
  String get emailNotVerifiedHint =>
      'Email not verified. Tap the icon to resend the link.';

  @override
  String get currentPasswordLabel => 'Current password';

  @override
  String get googleLinkedSuccessMessage => 'Google linked successfully.';

  @override
  String get unlinkGoogleConfirmTitle => 'Unlink Google?';

  @override
  String get unlinkGoogleConfirmMessage =>
      'You\'ll still be able to sign in with your password.';

  @override
  String get unlinkGoogleAction => 'Unlink';

  @override
  String get googleUnlinkedSuccessMessage => 'Google unlinked.';

  @override
  String get notLinkedLabel => 'Not linked';

  @override
  String get linkAction => 'Link';

  @override
  String get linkedNeverUsedLabel => 'Linked, never used';

  @override
  String lastUsedLabel(String date) {
    return 'Last used: $date';
  }

  @override
  String currentBalanceLabel(String balance) {
    return 'Current balance: $balance';
  }

  @override
  String get reasonOptionalLabel => 'Reason (optional)';

  @override
  String get saveAdjustmentAction => 'Save adjustment';

  @override
  String get reportTrendTitle => 'Trend';

  @override
  String get showChartTooltip => 'Show chart';

  @override
  String get showTableTooltip => 'Show table (accessible)';

  @override
  String get noDataForPeriod => 'No data for the selected period.';

  @override
  String get periodColumnLabel => 'Period';

  @override
  String get creditsColumnLabel => 'Income';

  @override
  String get debitsColumnLabel => 'Expenses';

  @override
  String get balanceColumnLabel => 'Balance';

  @override
  String get reportBreakdownTitle => 'Breakdown';

  @override
  String get noTransactionsForView => 'No transactions for this view.';

  @override
  String transactionCountLabel(int count) {
    return '$count transactions';
  }

  @override
  String get monthlyComparisonTitle => 'Monthly comparison';

  @override
  String get monthColumnLabel => 'Month';

  @override
  String get netColumnLabel => 'Net';

  @override
  String monthDetailSnackbar(
    String month,
    String credits,
    String debits,
    String net,
  ) {
    return '$month: income $credits, expenses $debits, net $net';
  }

  @override
  String get filtersTitle => 'Filters';

  @override
  String get typeLabel => 'Type';

  @override
  String get titleFieldLabel => 'Title';

  @override
  String get titleOrDescriptionFilterLabel => 'Title or description';

  @override
  String get historySearchHint => 'Search by title or description';

  @override
  String get minAmountLabel => 'Minimum amount';

  @override
  String get maxAmountLabel => 'Maximum amount';

  @override
  String get startDateLabel => 'Start date';

  @override
  String get endDateLabel => 'End date';

  @override
  String get anyLabel => 'Any';

  @override
  String get allCategoriesLabel => 'All categories';

  @override
  String get uncategorizedFilterLabel => 'No category';

  @override
  String get resetAction => 'Reset';

  @override
  String get applyAction => 'Apply';

  @override
  String get typeFilterAll => 'All';

  @override
  String get typeFilterAdjustments => 'Adjustments';

  @override
  String get typeFilterTransfers => 'Transfers';

  @override
  String get categoryPickerTitle => 'Category';

  @override
  String get categoriesLoadError => 'Couldn\'t load categories.';

  @override
  String get noCategoryLabel => 'No category';

  @override
  String get createAndSelectAction => 'Create and select';

  @override
  String get newCategoryAction => 'New category';

  @override
  String get newCategoryNameLabel => 'New category name';

  @override
  String get createCategoryError => 'Couldn\'t create the category. Try again.';

  @override
  String get categorySearchHint => 'Search categories';

  @override
  String get categorySearchNoResults => 'No categories found.';

  @override
  String get categorySortAlphabetical => 'A–Z';

  @override
  String get categorySortMostUsed => 'Most used';

  @override
  String get categoriesScreenTitle => 'Categories';

  @override
  String get categoriesMenuSubtitle => 'Sort, edit, delete or hide';

  @override
  String get categoriesHiddenSection => 'Hidden';

  @override
  String get categoriesHiddenHint =>
      'They don\'t show up when you pick a category, but stay on the transactions already recorded.';

  @override
  String categoryUsageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transactions',
      one: '1 transaction',
      zero: 'No transactions',
    );
    return '$_temp0';
  }

  @override
  String get categorySystemLabel => 'Built-in';

  @override
  String get editCategoryTitle => 'Edit category';

  @override
  String get categoryNameLabel => 'Name';

  @override
  String get categoryScopeLabel => 'Used for';

  @override
  String get categoryScopeDebit => 'Expenses';

  @override
  String get categoryScopeCredit => 'Income';

  @override
  String get categoryScopeBoth => 'Both';

  @override
  String get categoryColorLabel => 'Color';

  @override
  String get categoryNoColor => 'No color';

  @override
  String get editCategoryAction => 'Edit';

  @override
  String get hideCategoryAction => 'Hide';

  @override
  String get unhideCategoryAction => 'Show again';

  @override
  String get systemCategoryActionsHint =>
      'Built-in categories can\'t be edited or deleted, but you can hide them.';

  @override
  String deleteCategoryConfirmTitle(String name) {
    return 'Delete “$name”?';
  }

  @override
  String deleteCategoryInUseMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count transactions use this category: they will be left without a category.',
      one:
          '1 transaction uses this category: it will be left without a category.',
    );
    return '$_temp0';
  }

  @override
  String get deleteCategoryUnusedMessage =>
      'No transaction uses this category.';

  @override
  String get descriptionOptionalLabel => 'Description (optional)';

  @override
  String get loginAction => 'Log in';

  @override
  String get forgotPasswordAction => 'Forgot password?';

  @override
  String get usernameOrEmailLabel => 'Username or email';

  @override
  String get passwordLabel => 'Password';

  @override
  String get orDividerLabel => 'or';

  @override
  String get continueWithGoogleAction => 'Continue with Google';

  @override
  String get createAccountAction => 'Create an account';

  @override
  String get confirmRegistrationAction => 'Confirm registration';

  @override
  String get nextAction => 'Next';

  @override
  String get backAction => 'Back';

  @override
  String get accountStepTitle => 'Account';

  @override
  String get confirmPasswordLabel => 'Confirm password';

  @override
  String get profileStepTitle => 'Profile';

  @override
  String get backgroundColorLabel => 'Background color';

  @override
  String get walletStepTitle => 'Wallet';

  @override
  String get initialBalanceLabel => 'Initial balance (EUR)';

  @override
  String get acceptTermsLabel =>
      'I accept the terms of service and privacy policy';

  @override
  String registrationSummaryLabel(
    Object balance,
    Object firstName,
    Object lastName,
    Object username,
  ) {
    return 'Summary: $firstName $lastName, @$username, initial balance $balance';
  }

  @override
  String get completeRegistrationScreenTitle => 'Complete registration';

  @override
  String get backToLoginAction => 'Back to login';

  @override
  String googleSignInConfirmedMessage(String email) {
    return 'Signed in with Google as $email.';
  }

  @override
  String get localPasswordOptionalHint =>
      'Local password (optional: without it, you can only sign in with Google)';

  @override
  String get completeRegistrationAction => 'Complete registration';

  @override
  String get forgotPasswordScreenTitle => 'Forgot password';

  @override
  String get forgotPasswordSuccessMessage =>
      'If that address is registered, you\'ll receive an email shortly with instructions to reset your password.';

  @override
  String get forgotPasswordInstructionsMessage =>
      'Enter your email and we\'ll send you instructions to reset your password.';

  @override
  String get sendAction => 'Send';

  @override
  String get resetPasswordScreenTitle => 'New password';

  @override
  String get resetPasswordInstructionsMessage =>
      'Choose a new password for your account.';

  @override
  String get newPasswordLabel => 'New password';

  @override
  String get resetPasswordAction => 'Save password';

  @override
  String get resetPasswordSuccessMessage =>
      'Password updated. For your security every session was signed out: sign in with the new password.';

  @override
  String get requestNewLinkAction => 'Request a new link';

  @override
  String get verifyEmailScreenTitle => 'Confirm email';

  @override
  String get verifyEmailInProgressMessage => 'Confirming your email address…';

  @override
  String get verifyEmailSuccessMessage => 'Email address confirmed.';

  @override
  String get goToAppAction => 'Go to the app';

  @override
  String get resendVerificationAction => 'Send a new link';

  @override
  String get verificationResentMessage =>
      'We sent you a new link: check your inbox.';

  @override
  String get transactionDetailScreenTitle => 'Transaction details';

  @override
  String get editTooltip => 'Edit';

  @override
  String get deleteTooltip => 'Delete';

  @override
  String get commonDelete => 'Delete';

  @override
  String get deleteTransactionConfirmTitle => 'Delete this transaction?';

  @override
  String get deleteTransactionConfirmMessage =>
      'The balance will be updated accordingly.';

  @override
  String get openingBalanceKindLabel => 'Initial balance';

  @override
  String get balanceAdjustmentKindLabel => 'Balance adjustment';

  @override
  String get manualKindLabel => 'Manual';

  @override
  String get transferKindLabel => 'Transfer';

  @override
  String get walletLabel => 'Wallet';

  @override
  String get categoryLabel => 'Category';

  @override
  String get sourceLabel => 'Source';

  @override
  String get dateAndTimeLabel => 'Date and time';

  @override
  String get descriptionLabel => 'Description';

  @override
  String get createdLabel => 'Created';

  @override
  String get lastModifiedLabel => 'Last modified';

  @override
  String get editOpeningBalanceSheetTitle => 'Edit initial balance';

  @override
  String get editOpeningBalanceHint =>
      'This is the wallet\'s starting point, not a correction entry — changing it also changes past reports and charts.';

  @override
  String get saveOpeningBalanceAction => 'Save initial balance';

  @override
  String get addLinkedPaymentTooltip => 'Add linked payment';

  @override
  String get linkedPaymentsSectionTitle => 'Linked payments';

  @override
  String get linkedPaymentsTotalLabel => 'Combined total';

  @override
  String get linkedPaymentsCurrentLabel => 'Viewing';

  @override
  String get linkedPaymentsEmptyStateMessage => 'No linked payments yet.';

  @override
  String linkedPaymentsMemberCountLabel(int count) {
    return '$count payments';
  }

  @override
  String get mediaPickerRecentTab => 'Recent';

  @override
  String get mediaPickerLibraryTab => 'Library';

  @override
  String get mediaPickerSearchTab => 'Search';

  @override
  String get mediaPickerUploadTab => 'Upload';

  @override
  String get mediaLoadErrorMessage => 'Unable to load images.';

  @override
  String get mediaEmptyStateMessage => 'No images available.';

  @override
  String get mediaUntitledLabel => 'Untitled';

  @override
  String get mediaLibrarySearchHint => 'Search library';

  @override
  String get mediaSearchHint => 'Search images';

  @override
  String get mediaSearchMinCharsMessage =>
      'Type at least 2 characters to search.';

  @override
  String get mediaSearchNoResultsMessage => 'No results.';

  @override
  String get mediaSearchUnavailableMessage =>
      'Search is currently unavailable.';

  @override
  String get mediaSelectFailedMessage => 'Unable to select this image.';

  @override
  String get mediaCropScreenTitle => 'Crop image';

  @override
  String get mediaCameraAction => 'Camera';

  @override
  String get mediaGalleryAction => 'Gallery';

  @override
  String get mediaUploadFailedMessage => 'Upload failed. Try again.';

  @override
  String get mediaRenameDialogTitle => 'Rename image';

  @override
  String get mediaNameLabel => 'Name';

  @override
  String get mediaRenameFailedMessage => 'Unable to rename the image.';

  @override
  String get aiAssistantMenuTitle => 'AI assistant';

  @override
  String get aiAssistantMenuSubtitle =>
      'Analyze your finances with an AI model';

  @override
  String get aiAssistantTitle => 'AI assistant';

  @override
  String get aiUnavailableTitle => 'AI analysis unavailable';

  @override
  String get aiUnavailableBody =>
      'This server has not enabled AI analysis. Whoever runs the server can enable it by setting AI_KEY_ENCRYPTION_KEY.';

  @override
  String get aiSetupTitle => 'Get ready for your first analysis';

  @override
  String get aiSetupDoneTitle => 'All set';

  @override
  String aiSetupProgress(int done, int total) {
    return '$done of $total steps done';
  }

  @override
  String get aiSetupOptional => 'optional';

  @override
  String get aiSetupStepProvider => 'Provider, key and model';

  @override
  String get aiSetupStepProviderHint =>
      'Choose the AI service and enter your API key';

  @override
  String get aiSetupStepContext => 'Personal context';

  @override
  String get aiSetupStepContextHint =>
      'Goals and situation, for tailored advice';

  @override
  String get aiSetupStepPurposes => 'Wallet purposes';

  @override
  String get aiSetupStepPurposesHint => 'What each wallet is for';

  @override
  String get aiSetupStepFirstAnalysis => 'First analysis';

  @override
  String get aiSetupStepFirstAnalysisHint => 'From Reports, AI analysis card';

  @override
  String get aiProviderMenuTitle => 'Provider and API key';

  @override
  String get aiProviderMenuNotConfigured => 'Not set up';

  @override
  String get aiContextMenuTitle => 'Personal context';

  @override
  String get aiContextMenuFilled => 'Filled in';

  @override
  String get aiContextMenuEmpty => 'Not filled in yet';

  @override
  String get aiWalletPurposesMenuTitle => 'Wallet purposes';

  @override
  String aiWalletPurposesProgress(int done, int total) {
    return '$done of $total wallets with a purpose';
  }

  @override
  String get aiConsentMenuTitle => 'Privacy and consent';

  @override
  String get aiConsentMenuPending => 'To accept before the first analysis';

  @override
  String get aiConsentMenuAccepted => 'Accepted';

  @override
  String get aiConsentRevokeAction => 'Revoke';

  @override
  String get aiConsentRevokeConfirmTitle => 'Revoke consent?';

  @override
  String get aiConsentRevokeConfirmMessage =>
      'You will not be able to start analyses until you accept it again. Saved analyses stay in the history.';

  @override
  String get aiConsentTitle => 'Before you start';

  @override
  String get aiConsentIntro =>
      'AI analysis sends a summary of your data to the AI provider you choose, with your own API key. Before each send you will see exactly what is sent.';

  @override
  String get aiConsentSentTitle => 'What is sent';

  @override
  String get aiConsentSentAggregates =>
      'Totals, monthly trend, main categories and items of the chosen period';

  @override
  String get aiConsentSentWallets =>
      'Name, type, purpose and balance of the included wallets';

  @override
  String get aiConsentSentTransactions =>
      'The list of transactions: in analyses only if you turn it on, optionally with anonymized titles; in \"Ask the assistant\" always, since the answers rely on single transactions';

  @override
  String get aiConsentSentContext =>
      'Only if you turn it on: the personal context you wrote';

  @override
  String get aiConsentNeverTitle => 'What is never sent';

  @override
  String get aiConsentNeverBody =>
      'Email, name, username, account identifiers and images';

  @override
  String get aiConsentKeyTitle => 'Your API key';

  @override
  String get aiConsentKeyBody =>
      'It stays encrypted on the server and is never shown again or exported';

  @override
  String get aiConsentProviderTitle => 'The provider';

  @override
  String get aiConsentProviderBody =>
      'It handles the data under its own terms: check how long it keeps requests and whether it uses them for training';

  @override
  String get aiConsentRevokeTitle => 'You can change your mind';

  @override
  String get aiConsentRevokeBody =>
      'Revoke consent and delete analyses at any time from the AI assistant';

  @override
  String get aiConsentAccept => 'I understand, I accept';

  @override
  String get aiConsentDecline => 'Not now';

  @override
  String get aiProviderLabel => 'Provider';

  @override
  String get aiProviderCompatible =>
      'OpenAI-compatible (Mistral, Groq, OpenRouter, Ollama…)';

  @override
  String get aiProviderHintAnthropic =>
      'Create a key at console.anthropic.com → API keys.';

  @override
  String get aiProviderHintOpenai =>
      'Create a key at platform.openai.com → API keys.';

  @override
  String get aiProviderHintGemini =>
      'Create a key at aistudio.google.com → Get API key.';

  @override
  String get aiProviderHintCompatible =>
      'For any service exposing the OpenAI API: enter its address, usually ending in /v1.';

  @override
  String get aiBaseUrlLabel => 'Service address (base URL)';

  @override
  String get aiBaseUrlHelper =>
      'Private or local addresses (e.g. Ollama at home) only work if whoever runs the server allowed them.';

  @override
  String get aiApiKeyLabel => 'API key';

  @override
  String get aiApiKeyOptionalLabel => 'API key (if required)';

  @override
  String get aiApiKeyHelper =>
      'It is encrypted on the server: after saving you will only see its last characters.';

  @override
  String get aiApiKeyWillBeRemoved =>
      'The saved key will be removed when you save.';

  @override
  String aiApiKeyStored(String hint) {
    return 'Saved key $hint';
  }

  @override
  String get aiApiKeyReplace => 'Replace';

  @override
  String get aiApiKeyRemove => 'Remove';

  @override
  String get aiApiKeyShow => 'Show key';

  @override
  String get aiApiKeyHide => 'Hide key';

  @override
  String get aiModelLabel => 'Model';

  @override
  String get aiModelHelper =>
      'Press “Load models” to pick it from the provider\'s list, or type its name.';

  @override
  String aiModelsLoaded(int count) {
    return '$count models available';
  }

  @override
  String get aiModelsNoneFound =>
      'The provider returned no models: type the name by hand.';

  @override
  String get aiLoadModels => 'Load models';

  @override
  String get aiTestConnection => 'Test connection';

  @override
  String aiTestOk(String model, int ms) {
    return 'It works: $model answered in $ms ms.';
  }

  @override
  String aiTestOkKeyOnly(int ms) {
    return 'Key valid (answered in $ms ms). Choose a model to test it too.';
  }

  @override
  String get aiLastTestOk => 'Last test succeeded.';

  @override
  String get aiLastTestFailed => 'Last test failed.';

  @override
  String get aiAdvancedSettings => 'Advanced settings';

  @override
  String get aiMaxOutputTokensLabel => 'Maximum answer length (tokens)';

  @override
  String aiMaxOutputTokensHelper(int min, int max) {
    return 'Between $min and $max. Higher allows longer, costlier reports.';
  }

  @override
  String get aiPricesTitle => 'Prices (optional)';

  @override
  String get aiPricesHelper =>
      'Your model\'s price per million tokens, in the provider\'s currency: only used to estimate cost.';

  @override
  String get aiInputPriceLabel => 'Input';

  @override
  String get aiOutputPriceLabel => 'Output';

  @override
  String get aiDefaultIncludeTransactions =>
      'Include single transactions by default';

  @override
  String get aiDefaultIncludeTransactionsHint =>
      'More precise analyses, but more data sent and more tokens.';

  @override
  String get aiDefaultAnonymizeTitles => 'Anonymize titles by default';

  @override
  String get aiDefaultAnonymizeTitlesHint =>
      'Transaction names become “Item 1”, “Item 2”…';

  @override
  String get aiSaveSettings => 'Save';

  @override
  String get aiForgetProviderTitle => 'Forget this provider?';

  @override
  String get aiForgetProviderMessage =>
      'The saved API key is deleted from the server.';

  @override
  String get aiForgetProviderAction => 'Delete key and provider';

  @override
  String get aiContextIntro =>
      'This helps the AI give advice that fits your situation. Everything is optional and is only sent if you include the personal context in an analysis.';

  @override
  String get aiNotSpecified => 'Not specified';

  @override
  String get aiHouseholdLabel => 'People in the household';

  @override
  String aiHouseholdValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people',
      one: '1 person',
    );
    return '$_temp0';
  }

  @override
  String get aiHouseholdLess => 'One person fewer';

  @override
  String get aiHouseholdMore => 'One more person';

  @override
  String get aiIncomeTypeLabel => 'Income type';

  @override
  String get aiIncomeEmployee => 'Employee';

  @override
  String get aiIncomeSelfEmployed => 'Self-employed';

  @override
  String get aiIncomeStudent => 'Student';

  @override
  String get aiIncomeRetired => 'Retired';

  @override
  String get aiIncomeUnemployed => 'No work income';

  @override
  String get aiIncomeMixed => 'Mixed';

  @override
  String get aiIncomeOther => 'Other';

  @override
  String get aiAboutMeLabel => 'About me';

  @override
  String get aiAboutMeHint =>
      'E.g. I rent in Milan, I own a car, my salary arrives on the 27th';

  @override
  String get aiGoalsLabel => 'Goals';

  @override
  String get aiGoalsHint =>
      'E.g. save €5,000 by June, spend less on eating out';

  @override
  String get aiIgnoreLabel => 'Things to ignore or interpret';

  @override
  String get aiIgnoreHint =>
      'E.g. the transfer to Marco is a loan he pays back; in July I paid the yearly insurance';

  @override
  String get aiResponseStyleLabel => 'Answer style';

  @override
  String get aiStyleDefault => 'Standard';

  @override
  String get aiStyleConcise => 'Concise';

  @override
  String get aiStyleDetailed => 'Detailed';

  @override
  String get aiContextPrivacyNote =>
      'Do not write data such as IBANs, tax codes or passwords here: the analysis does not need them.';

  @override
  String get aiSaveContext => 'Save';

  @override
  String get aiWalletPurposesIntro =>
      'Say what each wallet is for: the AI can then tell you whether you use it as intended and how to organize better.';

  @override
  String get aiWalletPurposesEmpty => 'You have no active wallets yet.';

  @override
  String get aiWalletNoPurpose => 'No purpose';

  @override
  String get aiPurposeSuggestionDaily => 'Daily expenses';

  @override
  String get aiPurposeSuggestionSavings => 'Savings';

  @override
  String get aiPurposeSuggestionEmergency => 'Emergency fund';

  @override
  String get aiPurposeSuggestionHome => 'Home and bills';

  @override
  String get aiPurposeSuggestionLeisure => 'Leisure and travel';

  @override
  String get aiSavePurpose => 'Save purpose';

  @override
  String get aiNewAnalysisTitle => 'New AI analysis';

  @override
  String get aiHistoryTitle => 'Analysis history';

  @override
  String get aiHistoryMenuSubtitle => 'Reread, rename or delete analyses';

  @override
  String get aiNotReadyTitle => 'Set up AI analysis first';

  @override
  String get aiNotReadyBody =>
      'Choose a provider, enter the API key and a model.';

  @override
  String get aiGoToSetup => 'Set up';

  @override
  String get aiWhatToAnalyze => 'What to analyze';

  @override
  String get aiCustomQuestionLabel => 'Your question';

  @override
  String get aiCustomQuestionHint =>
      'E.g. how much did I spend eating out and how did it change over the months?';

  @override
  String get aiPeriodLabel => 'Period';

  @override
  String get aiPeriodLast30Days => 'Last 30 days';

  @override
  String get aiPeriodLast12Months => 'Last 12 months';

  @override
  String get aiPeriodCurrentMonth => 'This month';

  @override
  String get aiPeriodCurrentYear => 'This year';

  @override
  String get aiPeriodAllTime => 'Whole history';

  @override
  String get aiPeriodCustom => 'Custom';

  @override
  String aiPeriodUntil(String date) {
    return 'Up to $date';
  }

  @override
  String get aiWalletsLabel => 'Wallets';

  @override
  String get aiAllWallets => 'All';

  @override
  String get aiDataToSend => 'Data to send';

  @override
  String get aiDataToSendHint =>
      'Period, wallets and totals are always sent. More data means a richer analysis and more tokens.';

  @override
  String get aiSectionMonthly => 'Monthly trend';

  @override
  String get aiSectionCategories => 'Categories';

  @override
  String get aiSectionTitles => 'Top items';

  @override
  String get aiSectionTransfers => 'Transfers';

  @override
  String get aiSectionRecurring => 'Recurring expenses';

  @override
  String get aiSectionPersonalContext => 'Personal context';

  @override
  String get aiIncludeTransactions => 'Include single transactions';

  @override
  String get aiIncludeTransactionsHint =>
      'Useful for anomalies; sends date, amount, title and category of the most recent ones.';

  @override
  String aiMaxTransactionsValue(int count) {
    return 'max $count';
  }

  @override
  String get aiIncludeAdjustments => 'Include balance adjustments';

  @override
  String get aiIncludeAdjustmentsHint =>
      'They usually fix bookkeeping mistakes: better left out.';

  @override
  String get aiPreviewAction => 'Preview';

  @override
  String get aiPreviewTitle => 'Preview';

  @override
  String get aiPreviewMissing => 'No preview: go back and prepare one.';

  @override
  String aiPreviewSentTo(String provider, String model) {
    return 'Will be sent to $provider · $model';
  }

  @override
  String aiPreviewWallets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count wallets',
      one: '1 wallet',
    );
    return '$_temp0';
  }

  @override
  String get aiPreviewOnlyTotals => 'Only period, wallets and totals';

  @override
  String aiPreviewSections(String sections) {
    return 'Sections: $sections';
  }

  @override
  String get aiPreviewNoTransactions => 'No single transactions';

  @override
  String aiPreviewTransactions(int count, int omitted) {
    return '$count single transactions ($omitted older ones left out)';
  }

  @override
  String get aiPreviewAnonymized => 'Transaction titles anonymized';

  @override
  String get aiPreviewWithContext => 'Personal context included';

  @override
  String aiPreviewTokens(String tokens) {
    return '~$tokens input tokens';
  }

  @override
  String aiPreviewCost(String cost) {
    return 'max cost ~$cost';
  }

  @override
  String get aiInstructionsLabel => 'Instructions';

  @override
  String get aiInstructionsHint =>
      'You can edit them: they are the only part of the text you decide.';

  @override
  String get aiInstructionsRequired => 'Write the instructions before sending.';

  @override
  String get aiRestoreInstructions => 'Restore';

  @override
  String get aiSystemPromptLabel => 'Rules for the model';

  @override
  String get aiSystemPromptHint =>
      'Fixed: report format, correct use of data, safeguards';

  @override
  String get aiDataBlockLabel => 'Data sent';

  @override
  String get aiDataBlockHint =>
      'Generated by the server from your transactions, not editable';

  @override
  String get aiSendAction => 'Send and analyze';

  @override
  String get aiAnalysisTitle => 'AI analysis';

  @override
  String get aiDataSentTitle => 'What was sent';

  @override
  String get aiDataSentHint => 'Instructions and data exactly as sent';

  @override
  String get aiCopyAction => 'Copy text';

  @override
  String get aiShareAction => 'Share';

  @override
  String get aiCopied => 'Text copied';

  @override
  String get aiRefreshPreview => 'Refresh preview';

  @override
  String aiTokensUsed(String input, String output) {
    return '$input in / $output out tokens';
  }

  @override
  String aiCostValue(String cost) {
    return 'cost ~$cost';
  }

  @override
  String get aiThinking => 'The model is writing…';

  @override
  String get aiAnswerStopped => 'Stopped: the text above is partial.';

  @override
  String get aiAnswerTruncated =>
      'Answer cut at the token limit: you can raise it in the advanced settings.';

  @override
  String get aiWaitForAnswer => 'Wait for the answer to finish…';

  @override
  String get aiFollowUpUnavailable =>
      'Questions available once the report is done';

  @override
  String get aiFollowUpLimitReached => 'Question limit reached';

  @override
  String aiAskFollowUpHint(int left) {
    return 'Ask a question ($left left)';
  }

  @override
  String get aiStopAction => 'Stop';

  @override
  String get aiAskAction => 'Send question';

  @override
  String get aiHistoryEmpty =>
      'No analyses yet. Start one from Reports or ask a question in Ask the assistant.';

  @override
  String get aiDeleteAnalysisTitle => 'Delete the analysis?';

  @override
  String get aiDeleteAction => 'Delete';

  @override
  String get aiDeleteAllAction => 'Delete all';

  @override
  String get aiDeleteAllTitle => 'Delete all analyses?';

  @override
  String get aiDeleteAllMessage =>
      'Reports and conversations are deleted permanently.';

  @override
  String get aiRenameAction => 'Rename';

  @override
  String get aiRenameTitle => 'Rename analysis';

  @override
  String get aiCancel => 'Cancel';

  @override
  String get aiReportsCardTitle => 'AI analysis';

  @override
  String get aiReportsCardBody =>
      'Have your numbers explained: a personalized report and follow-up questions.';

  @override
  String get aiReportsCardSetupBody =>
      'Connect your preferred AI provider to get personalized reports on your finances.';

  @override
  String get aiReportsCardStart => 'Analyze';

  @override
  String get aiHistoryAnalyzeAction =>
      'Analyze the filtered transactions with AI';

  @override
  String get aiHistoryAnalyzeAdjustments =>
      'AI analysis looks at income and expenses: remove the \"adjustments\" filter to analyze these transactions.';

  @override
  String get aiHistoryAnalyzeTransfers =>
      'Transfers move money between your wallets and are not analyzed: remove the \"transfers\" filter.';

  @override
  String get aiPeriodLastMonth => 'Last month';

  @override
  String get aiPeriodLastQuarter => 'Last quarter';

  @override
  String get aiDateFrom => 'From';

  @override
  String get aiDateTo => 'To';

  @override
  String get aiDateFromEmpty => 'The beginning';

  @override
  String get aiDateToEmpty => 'Today';

  @override
  String get aiDateClear => 'Clear date';

  @override
  String get aiFiltersTitle => 'Filters';

  @override
  String get aiFiltersFromHistoryTitle => 'Filters from History';

  @override
  String get aiFiltersHint =>
      'The analysis only covers transactions matching these filters. Balances and transfers are left out.';

  @override
  String get aiFilterExpenses => 'Expenses only';

  @override
  String get aiFilterIncome => 'Income only';

  @override
  String aiFilterCategory(String name) {
    return 'Category: $name';
  }

  @override
  String aiFilterTitle(String text) {
    return 'Contains “$text”';
  }

  @override
  String aiFilterAmountMin(String amount) {
    return 'From $amount';
  }

  @override
  String aiFilterAmountMax(String amount) {
    return 'Up to $amount';
  }

  @override
  String get aiProviderOnDevice => 'On device';

  @override
  String get errorCodeAiOnDeviceDisabled =>
      'On-device analysis is not enabled on this server.';

  @override
  String get errorCodeAiLocalConsentRequired =>
      'Accept the on-device analysis notice to continue.';

  @override
  String get errorCodeAiAnalysisOnDevice =>
      'This analysis was written on the phone: continue it there.';

  @override
  String get errorCodeAiAnalysisNotOnDevice =>
      'This analysis was written by a cloud provider.';

  @override
  String get errorCodeAiMessageFinished => 'This answer was already saved.';

  @override
  String get errorCodeAiLocalEngineError => 'The on-device model failed.';

  @override
  String get errorCodeAiLocalOutOfMemory =>
      'Not enough memory: choose a smaller model or a shorter context.';

  @override
  String get errorCodeAiLocalContextTooLong =>
      'The text doesn\'t fit the model\'s context: use the compact profile, a larger context or fewer transactions.';

  @override
  String get errorCodeAiLocalTimeout =>
      'The phone took too long and generation was stopped.';

  @override
  String get errorCodeAiLocalModelMissing =>
      'No model installed on the phone: download one from the AI assistant.';

  @override
  String get errorCodeAiLocalInterrupted =>
      'Generation on the phone was interrupted.';

  @override
  String get errorCodeAiLocalUnsupported =>
      'This device cannot run models locally.';

  @override
  String get errorCodeAiLocalTooHot =>
      'The phone is too hot to run the model. Let it cool down for a few minutes and try again.';

  @override
  String get aiCloudOnlyHereNote =>
      'Here analyses only use cloud providers with your API key. The model on your phone stays active in the app.';

  @override
  String get googleWebLinkDialogTitle => 'Choose the Google account to link';

  @override
  String get mediaCropRotateLeft => 'Rotate left';

  @override
  String get mediaCropRotateRight => 'Rotate right';

  @override
  String get mediaCropConfirm => 'Crop';

  @override
  String get aiDownloadAction => 'Download (.md)';

  @override
  String get aiModeCloud => 'Cloud';

  @override
  String get aiModeOnDevice => 'On device';

  @override
  String get aiLocalModeIntro =>
      'The model runs on the phone: your data goes to no outside AI provider. The server prepares the data and keeps reports and questions in the history, as with the cloud.';

  @override
  String get aiLocalModelsTitle => 'On-device models';

  @override
  String get aiLocalRuntimeTitle => 'Runtime settings';

  @override
  String get aiLocalNoModel =>
      'No active model. Download or import one to use on-device analysis.';

  @override
  String get aiLocalNoModelShort => 'No model installed';

  @override
  String get aiLocalChooseModel => 'Choose a model';

  @override
  String get aiLocalNotReadyBody =>
      'An on-device analysis needs an installed model. Download one from On-device models.';

  @override
  String get aiLocalConsentMenuTitle => 'On-device disclosure';

  @override
  String get aiLocalConsentIntro =>
      'With on-device analysis the AI model runs on your phone. Before each analysis you see exactly which data it is given.';

  @override
  String get aiLocalConsentWhereTitle => 'Where the data is processed';

  @override
  String get aiLocalConsentWhereBody =>
      'On the phone, with no connection to the model: no outside AI provider receives your data.';

  @override
  String get aiLocalConsentStoredTitle => 'What the server keeps';

  @override
  String get aiLocalConsentStoredBody =>
      'The server prepares the data summary and keeps reports and questions in the history, so you find them on every device.';

  @override
  String get aiLocalConsentMistakesTitle => 'The model can be wrong';

  @override
  String get aiLocalConsentMistakesBody =>
      'Models that run on a phone are small: they can mix up numbers. Check them before deciding.';

  @override
  String get aiLocalConsentModelTitle => 'The model';

  @override
  String get aiLocalConsentModelBody =>
      'You download it from Hugging Face, which sees your IP address. Each model has its own license, shown before the download.';

  @override
  String get aiSetupStepLocalModel => 'Model on the phone';

  @override
  String get aiSetupStepLocalModelHint =>
      'Download a model and accept the on-device disclosure';

  @override
  String get aiLocalBackendGpu => 'GPU';

  @override
  String get aiLocalBackendCpu => 'CPU';

  @override
  String get aiLocalBackendNpu => 'NPU';

  @override
  String get aiLocalBackendLabel => 'Runs on';

  @override
  String get aiLocalBackendGpuHint => 'Faster. Recommended.';

  @override
  String get aiLocalBackendCpuHint =>
      'Slower and uses more memory; with LiteRT-LM the context goes up to 8k.';

  @override
  String aiLocalContextShort(String size) {
    return '$size context';
  }

  @override
  String aiLocalOutputShort(int count) {
    return 'answer up to $count tokens';
  }

  @override
  String aiLocalContextLabel(String count) {
    return 'Context: $count tokens';
  }

  @override
  String get aiLocalContextHint =>
      'How much text the model keeps in mind: data, report and questions.';

  @override
  String get aiLocalContextMemoryWarning =>
      'More context uses more memory. If the app closes during an analysis, lower it.';

  @override
  String aiLocalOutputLabel(String count) {
    return 'Longest answer: $count tokens';
  }

  @override
  String get aiLocalOutputHint =>
      'A typical report uses 600–1,000. More room for the answer leaves less for the data.';

  @override
  String aiLocalTemperatureLabel(String value) {
    return 'Temperature: $value';
  }

  @override
  String get aiLocalTemperatureHint =>
      'Low: answers closer to the numbers. High: more varied.';

  @override
  String get aiLocalSpeedTitle => 'Speed';

  @override
  String aiLocalSpeedValue(String prefill, String decode) {
    return 'Reading $prefill tokens/s · writing $decode tokens/s';
  }

  @override
  String get aiLocalSpeedMeasured => 'Measured on this phone';

  @override
  String get aiLocalSpeedCatalog =>
      'Indicative, measured on a Galaxy S26 Ultra';

  @override
  String get aiLocalSpeedFallback => 'Not measured yet: a cautious guess';

  @override
  String get aiLocalMeasure => 'Measure speed';

  @override
  String get aiLocalMeasuring => 'Measuring…';

  @override
  String get aiLocalResetDefaults => 'Restore defaults';

  @override
  String get aiLocalDeviceTitle => 'This phone';

  @override
  String aiLocalDeviceRam(String size) {
    return 'RAM $size';
  }

  @override
  String aiLocalDeviceFree(String size) {
    return '$size free';
  }

  @override
  String get aiLocalDeviceUnknown => 'Memory and storage unknown';

  @override
  String get aiLocalWifiOnly => 'Download on Wi-Fi only';

  @override
  String get aiLocalWifiOnlyHint =>
      'Models weigh a few GB: off Wi-Fi the download waits and resumes by itself.';

  @override
  String get aiLocalPickingFile => 'Preparing the file…';

  @override
  String get aiLocalImporting => 'Importing and checking the model…';

  @override
  String get aiLocalInstalledTitle => 'Installed';

  @override
  String get aiLocalInUse => 'in use';

  @override
  String get aiLocalUnverified => 'not verified';

  @override
  String get aiLocalUseModel => 'Use this model';

  @override
  String get aiLocalEngineLitert => 'LiteRT-LM';

  @override
  String get aiLocalEngineLitertHint =>
      'On the GPU, fast. Models prepared by Google.';

  @override
  String get aiLocalEngineLlama => 'llama.cpp';

  @override
  String get aiLocalEngineLlamaHint =>
      'Any GGUF file and quantization, on the CPU: slower.';

  @override
  String get aiLocalRecommended => 'Recommended';

  @override
  String get aiLocalRamFits => 'Enough RAM';

  @override
  String get aiLocalRamTight => 'RAM tight';

  @override
  String get aiLocalRamInsufficient => 'Not enough RAM';

  @override
  String get aiLocalRamUnknown => 'RAM unknown';

  @override
  String get aiLocalRamWarningTitle => 'Not enough memory';

  @override
  String get aiLocalRamWarningMessage =>
      'This phone has less RAM than the model needs: it may not start or may close the app.';

  @override
  String get aiLocalDownloadAnyway => 'Download anyway';

  @override
  String get aiLocalDownload => 'Download';

  @override
  String aiLocalProgress(String done, String total) {
    return '$done of $total';
  }

  @override
  String get aiLocalQueued => 'Queued';

  @override
  String aiLocalPaused(String progress) {
    return 'Paused · $progress';
  }

  @override
  String get aiLocalWaitingForWifi => 'Waiting for Wi-Fi';

  @override
  String get aiLocalVerifying => 'Checking the file…';

  @override
  String get aiLocalPause => 'Pause';

  @override
  String get aiLocalResume => 'Resume';

  @override
  String get aiLocalRetry => 'Retry';

  @override
  String get aiLocalCancel => 'Cancel';

  @override
  String aiLocalLicenseBody(String size, String license) {
    return 'The file is $size and comes from Hugging Face. The model is distributed under the $license license: by downloading it you accept it.';
  }

  @override
  String get aiLocalGatedBody =>
      'This model is gated: accept the license on its Hugging Face page and enter a read token.';

  @override
  String get aiLocalAcceptAndDownload => 'Accept and download';

  @override
  String get aiLocalDeleteTitle => 'Delete the model?';

  @override
  String aiLocalDeleteMessage(String name) {
    return '$name will be removed from the phone. Analyses already made stay in the history.';
  }

  @override
  String aiLocalDeleted(String size) {
    return 'Model deleted: $size freed';
  }

  @override
  String get aiLocalImportFile => 'Import a file';

  @override
  String get aiLocalImportUrl => 'Download from URL';

  @override
  String get aiLocalImportAction => 'Import';

  @override
  String get aiLocalUrlLabel => 'File https address';

  @override
  String get aiLocalNameLabel => 'Model name';

  @override
  String get aiLocalQuantLabel => 'Quantization (e.g. Q4_K_M)';

  @override
  String get aiLocalShaLabel => 'SHA-256 (optional)';

  @override
  String get aiLocalShaHelper =>
      'If you enter it the file is checked; otherwise the model stays \"not verified\".';

  @override
  String get aiLocalShaInvalid => 'Must be 64 hexadecimal characters.';

  @override
  String aiLocalImported(String name) {
    return '$name imported';
  }

  @override
  String aiLocalImportedUnverified(String name) {
    return '$name imported, not verified';
  }

  @override
  String get aiLocalTokenAction => 'Hugging Face token';

  @override
  String get aiLocalTokenLabel => 'Read token';

  @override
  String get aiLocalTokenHelper =>
      'Needed only for gated models. It stays on the phone and is sent only to huggingface.co.';

  @override
  String get aiLocalTokenStored => 'A token is saved on this phone.';

  @override
  String get aiLocalTokenNone => 'No token saved.';

  @override
  String get aiLocalTokenSaved => 'Token saved';

  @override
  String get aiLocalTokenRemoved => 'Token removed';

  @override
  String get aiCompactProfile => 'Compact profile';

  @override
  String get aiCompactProfileHint =>
      'Less detail and shorter rules: a shorter prompt.';

  @override
  String get aiCompactProfileHintLocal =>
      'Recommended on the phone: less detail, shorter rules and a prompt that fits the model\'s context.';

  @override
  String aiPreviewOnDevice(String model) {
    return 'Processed on the phone with $model';
  }

  @override
  String get aiPreviewNoCost => 'No cost';

  @override
  String aiPreviewCompacted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count details were reduced to fit the limit.',
      one: 'One detail was reduced to fit the limit.',
    );
    return '$_temp0';
  }

  @override
  String get aiRunOnDeviceAction => 'Run on the phone';

  @override
  String aiLocalContextUse(String used, String total) {
    return 'Context: $used of $total tokens';
  }

  @override
  String aiLocalContextParts(String input, String output) {
    return 'data $input · answer $output';
  }

  @override
  String get aiLocalCountExact => 'exact count';

  @override
  String get aiLocalCountEstimated => 'estimate';

  @override
  String get aiLocalContextTight =>
      'Nearly full: follow-up questions will have little room.';

  @override
  String get aiLocalContextOverflow =>
      'It doesn\'t fit the model\'s context. Try one of these:';

  @override
  String get aiLocalFixCompact => 'Compact profile';

  @override
  String get aiLocalFixFewerTransactions => 'Fewer transactions';

  @override
  String get aiLocalFixShorterAnswer => 'Shorter answer';

  @override
  String get aiLocalFixLargerContext => 'Larger context';

  @override
  String aiLocalTimeEstimate(String low, String high) {
    return 'Estimated time: $low–$high';
  }

  @override
  String get aiLocalTimeRough =>
      'A rough guess: measure the speed in Runtime settings.';

  @override
  String get aiLocalWarnWarm => 'The phone is warm: it will be slower.';

  @override
  String get aiLocalWarnBattery => 'Battery below 15%: plug in the charger.';

  @override
  String get aiLocalWarnMemory =>
      'Little free memory: close other apps if the analysis stops.';

  @override
  String get aiLocalKeepOpen =>
      'The phone is writing. You can leave the app: we\'ll let you know when it is done.';

  @override
  String aiLocalTokensPerSecond(String value) {
    return '$value tokens/s';
  }

  @override
  String get errorCodeAiLocalDownloadNetwork =>
      'The download was interrupted by the network: resume when the connection is back.';

  @override
  String get errorCodeAiLocalDownloadGated =>
      'Gated model: accept the license on Hugging Face and enter a valid token.';

  @override
  String get errorCodeAiLocalDownloadNotFound =>
      'File not found on the server.';

  @override
  String get errorCodeAiLocalDownloadHttp => 'The server refused the download.';

  @override
  String get errorCodeAiLocalDownloadNoSpace =>
      'Not enough space on the phone for this model.';

  @override
  String get errorCodeAiLocalDownloadChecksum =>
      'The downloaded file doesn\'t match the expected one and was discarded.';

  @override
  String get errorCodeAiLocalDownloadInsecureUrl =>
      'The address must start with https://.';

  @override
  String get errorCodeAiLocalImportUnknownFormat =>
      'Unknown format: .gguf or .litertlm files are needed.';

  @override
  String get aiFeaturesSwitchTitle => 'AI features';

  @override
  String get aiFeaturesSwitchSubtitle =>
      'AI assistant, analyses in Reports and History, wallet purposes. Turning them off deletes nothing: analyses, keys and models stay where they are.';

  @override
  String get aiRunModelLabel => 'Model';

  @override
  String get aiPendingTitle => 'Unsent answers';

  @override
  String get aiPendingIntro =>
      'Reports and answers written on this phone that the server doesn\'t have yet: the network was down when they finished, or the server refused them. They stay here until whoever wrote them sends or deletes them. Anyone using the app on this phone can read them.';

  @override
  String get aiPendingEmpty => 'Nothing waiting: the server has everything.';

  @override
  String get aiPendingReport => 'Report';

  @override
  String get aiPendingAnswer => 'Answer to a question';

  @override
  String get aiPendingUnknownOwner => 'unknown account';

  @override
  String get aiPendingWaiting =>
      'Waiting to be sent: it goes by itself when its author signs in or reopens the app.';

  @override
  String aiPendingRefused(String reason) {
    return 'Refused by the server: $reason';
  }

  @override
  String get aiPendingResend => 'Send now';

  @override
  String get aiPendingSent => 'Sent: it is now in the history.';

  @override
  String get aiPendingRefusedAgain =>
      'The server still refuses it: you can read it here or delete it.';

  @override
  String get aiPendingNotOwner => 'Only its author can send it.';

  @override
  String aiPendingOwnerOnly(String owner) {
    return 'Only $owner can send or delete it.';
  }

  @override
  String get aiPendingDeleteTitle => 'Delete this answer?';

  @override
  String get aiPendingDeleteMessage =>
      'The text exists only on this phone: deleting it loses it.';

  @override
  String aiPendingBanner(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count answers written on the phone are not on the server yet',
      one: 'One answer written on the phone is not on the server yet',
    );
    return '$_temp0';
  }

  @override
  String get aiLocalFollowUpUnsupported =>
      'This analysis was written on a phone: continue the questions from an Android phone with a model installed.';

  @override
  String get aiLocalFollowUpNoModel =>
      'Answering needs a model on the phone: install one from On-device models.';

  @override
  String aiLocalFollowUpOtherModel(String report, String current) {
    return 'The report\'s model ($report) is no longer installed: $current will answer.';
  }

  @override
  String get bgWorkTitle => 'On-device AI';

  @override
  String get bgWorkChannel => 'Work in progress';

  @override
  String get bgWorkStop => 'Stop';

  @override
  String bgDownloading(String name, int percent) {
    return 'Downloading $name · $percent%';
  }

  @override
  String bgVerifying(String name) {
    return 'Checking $name';
  }

  @override
  String bgWaitingWifi(String name) {
    return '$name · waiting for Wi-Fi';
  }

  @override
  String bgQueued(String name) {
    return '$name · queued';
  }

  @override
  String get aiNotifyChannel => 'AI analyses';

  @override
  String get notifyModelReadyTitle => 'Model ready';

  @override
  String notifyModelReadyBody(String name) {
    return '$name is installed: you can use it for analyses.';
  }

  @override
  String get notifyDownloadFailedTitle => 'Download failed';

  @override
  String get aiLeaveTitle => 'The analysis is still running';

  @override
  String get aiLeaveBody =>
      'The phone is still writing. You can stop it (what was written so far is saved), stay here or let it go on in the background: a notification tells you when it is done.';

  @override
  String get aiLeaveStop => 'Stop';

  @override
  String get aiLeaveStay => 'Stay';

  @override
  String get aiLeaveBackground => 'Continue in background';

  @override
  String bgWritingReport(int words) {
    return 'Writing the report · $words words';
  }

  @override
  String bgWritingAnswer(int words) {
    return 'Writing the answer · $words words';
  }

  @override
  String get notifyReportReadyTitle => 'Analysis ready';

  @override
  String get notifyAnswerReadyTitle => 'Answer ready';

  @override
  String get notifyAnalysisFailedTitle => 'Analysis interrupted';

  @override
  String get notifyAnalysisFallbackBody => 'Tap to read it.';

  @override
  String get aiChatTitle => 'Ask the assistant';

  @override
  String get aiChatMenuSubtitle =>
      'Free-form questions about your transactions, as in a chat';

  @override
  String get aiChatIntro =>
      'Ask a question about your transactions: when you paid something, how much you spend on an item, which expenses you have every year.';

  @override
  String get aiChatExamplesTitle => 'For example';

  @override
  String get aiChatExampleInsurance => 'When did I pay the car insurance?';

  @override
  String get aiChatExampleFuel =>
      'How much do I spend on fuel per month on average?';

  @override
  String get aiChatExampleYearly => 'Which expenses do I pay once a year?';

  @override
  String get aiChatHint => 'Write your question';

  @override
  String get aiChatDataNoteCloud =>
      'To answer, it sends the provider your whole history, with the transaction list and its titles.';

  @override
  String get aiChatDataNoteOnDevice =>
      'The model on the phone reads your whole history with the transaction list; if it doesn\'t all fit, each question gets the older transactions that match it.';

  @override
  String get aiChatAttachmentChip => 'Transactions searched';

  @override
  String get aiChatAttachmentTitle => 'Transactions added to the question';

  @override
  String get aiHistoryFilterAll => 'All';

  @override
  String get aiHistoryFilterReports => 'Reports';

  @override
  String get aiHistoryFilterChats => 'Chats';

  @override
  String aiChatToolSearch(String query) {
    return 'Searching transactions: $query';
  }

  @override
  String get aiChatToolSearchAll => 'Searching transactions';

  @override
  String aiChatToolSum(String query) {
    return 'Adding up totals: $query';
  }

  @override
  String get aiChatToolSumAll => 'Adding up totals';

  @override
  String aiChatSearchesTitle(int count) {
    return 'Searches made: $count';
  }

  @override
  String aiChatSearchRows(int count) {
    return 'Rows: $count';
  }
}
