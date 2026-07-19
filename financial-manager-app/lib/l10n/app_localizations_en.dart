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
  String get accountSecurityMenuTitle => 'Security';

  @override
  String get accountSecurityMenuSubtitle => 'Password, active sessions, logout';

  @override
  String get accountLinkedAccountsMenuTitle => 'Linked accounts';

  @override
  String get accountPreferencesMenuTitle => 'Preferences';

  @override
  String get accountPreferencesMenuSubtitle =>
      'Theme, timezone, language, balance';

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
  String exportSavedMessage(String path) {
    return 'Export saved to $path';
  }

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
      'CSV for transactions, JSON for profile, wallet, categories, templates, and transactions.';

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
  String get groupByTitleOption => 'By title';

  @override
  String get groupByCategoryOption => 'By category';

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
  String get resetAction => 'Reset';

  @override
  String get applyAction => 'Apply';

  @override
  String get typeFilterAll => 'All';

  @override
  String get typeFilterAdjustments => 'Adjustments';

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
}
