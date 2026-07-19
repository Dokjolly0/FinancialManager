// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get appTitle => 'FinancialManager';

  @override
  String get commonRetry => 'Riprova';

  @override
  String get commonCancel => 'Annulla';

  @override
  String get commonConfirm => 'Conferma';

  @override
  String get errorGenericTitle => 'Qualcosa non ha funzionato';

  @override
  String get errorNetworkTitle => 'Connessione assente';

  @override
  String get errorSessionExpiredTitle => 'Sessione scaduta';

  @override
  String get emptyStateDefaultMessage => 'Nessun elemento da mostrare.';

  @override
  String get errorCodeNetworkError =>
      'Connessione assente. Controlla la rete e riprova.';

  @override
  String get errorCodeSessionExpired => 'Sessione scaduta. Accedi di nuovo.';

  @override
  String get errorCodeRateLimitedGeneric =>
      'Troppi tentativi. Riprova più tardi.';

  @override
  String errorCodeRateLimitedWithSeconds(int seconds) {
    return 'Troppi tentativi. Riprova tra $seconds secondi.';
  }

  @override
  String get errorCodeUnknownError =>
      'Si è verificato un errore imprevisto. Riprova.';

  @override
  String get errorCodeValidationError => 'Controlla i campi evidenziati.';

  @override
  String get errorCodeBadRequest => 'Richiesta malformata.';

  @override
  String get errorCodeUnauthorized => 'Autenticazione richiesta o non valida.';

  @override
  String get errorCodeForbidden => 'Operazione non consentita.';

  @override
  String get errorCodeNotFound => 'Risorsa non trovata.';

  @override
  String get errorCodeConflict =>
      'La risorsa è cambiata rispetto a quanto atteso.';

  @override
  String get errorCodeInternalError => 'Si è verificato un errore interno.';

  @override
  String get errorCodeEmailInUse => 'Email già registrata.';

  @override
  String get errorCodeUsernameInUse => 'Nome utente già in uso.';

  @override
  String get errorCodeInvalidCredentials => 'Credenziali non valide.';

  @override
  String get errorCodeInvalidCurrentPassword =>
      'La password attuale non è corretta.';

  @override
  String get errorCodeInvalidOrExpiredToken =>
      'Il link non è valido o è scaduto.';

  @override
  String get errorCodeInvalidGoogleToken => 'Token Google non valido.';

  @override
  String get errorCodeGoogleAccountAlreadyLinked =>
      'Questo account Google è già collegato a un altro utente.';

  @override
  String get errorCodeNoAlternativeLoginMethod =>
      'Imposta prima una password per poter scollegare Google.';

  @override
  String get errorCodeIdempotencyKeyReused =>
      'La richiesta è già stata inviata con dati diversi.';

  @override
  String get errorCodeAccountDeletionPending =>
      'Questo account è in attesa di eliminazione.';

  @override
  String get errorCodeAccountLocked =>
      'Questo account è temporaneamente bloccato. Riprova più tardi.';

  @override
  String get errorCodeNoPasswordSet =>
      'Nessuna password impostata per questo account.';

  @override
  String get errorCodeReauthRequired =>
      'Conferma la password per collegare un account Google.';

  @override
  String get errorCodeCategoryAlreadyExists =>
      'Esiste già una categoria con questo nome per questa direzione.';

  @override
  String get errorCodeSystemCategoryNotEditable =>
      'Le categorie di sistema non possono essere modificate.';

  @override
  String get errorCodeSystemCategoryNotDeletable =>
      'Le categorie di sistema non possono essere eliminate.';

  @override
  String get errorCodeTemplateAlreadyExists =>
      'Esiste già un modello con questo titolo per questa direzione.';

  @override
  String get errorCodeExportNotReady => 'L\'esportazione non è ancora pronta.';

  @override
  String get errorCodeUploadTooLarge =>
      'Il file supera la dimensione massima consentita.';

  @override
  String get errorCodeImageTooLarge =>
      'L\'immagine supera le dimensioni massime consentite.';

  @override
  String get errorCodeUnsupportedImageFormat =>
      'Questo formato immagine non è supportato. Usa JPEG, PNG o WebP.';

  @override
  String get errorCodeImageFetchFailed =>
      'Impossibile scaricare l\'immagine selezionata.';

  @override
  String get errorCodeImageSearchFailed =>
      'Ricerca immagini non disponibile al momento.';

  @override
  String get errorCodeMediaInUse =>
      'L\'immagine è ancora in uso e non può essere eliminata.';

  @override
  String get errorCodeNotEditable =>
      'Solo le operazioni standard possono essere modificate.';

  @override
  String get errorCodeOpeningBalanceNotDeletable =>
      'Il saldo iniziale non può essere eliminato direttamente.';

  @override
  String get errorCodeCategoryNotFound => 'Categoria non trovata.';

  @override
  String get errorCodeTemplateNotFound => 'Modello non trovato.';

  @override
  String get errorCodeMediaNotFound => 'Immagine non trovata.';

  @override
  String get errorCodeRequiredField => 'Campo obbligatorio.';

  @override
  String get errorCodeUsernameLengthInvalid =>
      'Deve avere tra 3 e 40 caratteri.';

  @override
  String get errorCodeInvalidEmail => 'Email non valida.';

  @override
  String get errorCodePasswordTooShort => 'Deve avere almeno 8 caratteri.';

  @override
  String get errorCodePasswordsDoNotMatch => 'Le password non coincidono.';

  @override
  String get errorCodeInvalidColorFormat => 'Formato colore non valido.';

  @override
  String get errorCodeNegativeNotAllowed => 'Non può essere negativo.';

  @override
  String get errorCodeCurrencyNotSupported =>
      'Solo EUR è supportato in questa versione.';

  @override
  String get errorCodeTermsNotAccepted =>
      'Devi accettare i termini per procedere.';

  @override
  String get errorCodeInvalidUuid => 'Deve essere un UUID valido.';

  @override
  String get errorCodeInvalidDirection => 'Deve essere CREDIT o DEBIT.';

  @override
  String get errorCodeAmountNotPositive => 'Deve essere maggiore di zero.';

  @override
  String get errorCodeAmountImplausible => 'Importo non plausibile.';

  @override
  String get errorCodeTitleLengthInvalid => 'Deve avere tra 1 e 120 caratteri.';

  @override
  String get errorCodeCurrencyMismatch =>
      'Deve corrispondere alla valuta del portafoglio.';

  @override
  String get errorCodeMustBeInteger => 'Deve essere un numero intero.';

  @override
  String get errorCodeInvalidRfc3339Date => 'Deve essere una data valida.';

  @override
  String get errorCodeInvalidCategoryScope =>
      'Deve essere DEBIT, CREDIT o BOTH.';

  @override
  String get errorCodeCategoryNameLengthInvalid =>
      'Deve avere tra 1 e 80 caratteri.';

  @override
  String get errorCodeInvalidTheme => 'Deve essere system, light o dark.';

  @override
  String get errorCodeInvalidFirstDayOfWeek => 'Deve essere monday o sunday.';

  @override
  String get errorCodeInvalidExportFormat => 'Deve essere csv o json.';

  @override
  String get errorCodeInvalidTimezone => 'Fuso orario non valido.';

  @override
  String get errorCodeInvalidPreset => 'Valore non valido.';

  @override
  String get errorCodeCustomRangeRequired =>
      '\'from\' e \'to\' sono obbligatori con preset=custom.';

  @override
  String get errorCodeInvalidGroupBy => 'Deve essere title o category.';

  @override
  String get errorCodeInvalidMediaKind =>
      'Deve essere profile, transaction o category.';

  @override
  String get errorCodeProviderNotSupported => 'Provider non supportato.';

  @override
  String get errorCodeInvalidAmount => 'Importo non valido.';

  @override
  String get errorCodeRegistrationSessionExpired =>
      'Sessione di registrazione scaduta. Riprova con Google.';

  @override
  String get errorCodeExportFailed => 'Esportazione non riuscita. Riprova.';

  @override
  String get commonSave => 'Salva';

  @override
  String get commonContinue => 'Continua';

  @override
  String get accountScreenTitle => 'Account';

  @override
  String get accountLogoutConfirmTitle => 'Vuoi uscire?';

  @override
  String get accountLogoutAction => 'Esci';

  @override
  String get accountLogoutAllConfirmTitle => 'Uscire da tutti i dispositivi?';

  @override
  String get accountLogoutAllConfirmMessage =>
      'Tutte le sessioni attive verranno terminate.';

  @override
  String get accountLogoutAllAction => 'Esci ovunque';

  @override
  String get accountLogoutAllMenuTitle => 'Esci da tutti i dispositivi';

  @override
  String get accountProfileLoadError => 'Impossibile caricare il profilo.';

  @override
  String get accountWalletLabel => 'Portafoglio';

  @override
  String get accountBalanceAdjustmentAction => 'Rettifica saldo';

  @override
  String get accountSecurityMenuTitle => 'Sicurezza';

  @override
  String get accountSecurityMenuSubtitle => 'Password, sessioni attive, logout';

  @override
  String get accountLinkedAccountsMenuTitle => 'Account collegati';

  @override
  String get accountPreferencesMenuTitle => 'Preferenze';

  @override
  String get accountPreferencesMenuSubtitle =>
      'Tema, fuso orario, lingua, saldo';

  @override
  String get accountDataMenuTitle => 'Dati';

  @override
  String get accountDataMenuSubtitle => 'Esporta o elimina il tuo account';

  @override
  String get accountPreferencesLoadError =>
      'Impossibile caricare le preferenze.';

  @override
  String get themeLabel => 'Tema';

  @override
  String get themeOptionSystem => 'Sistema';

  @override
  String get themeOptionLight => 'Chiaro';

  @override
  String get themeOptionDark => 'Scuro';

  @override
  String get firstDayOfWeekLabel => 'Primo giorno della settimana';

  @override
  String get weekdayMonday => 'Lunedì';

  @override
  String get weekdaySunday => 'Domenica';

  @override
  String get hideBalanceOnOpenTitle => 'Nascondi saldo all\'apertura';

  @override
  String get hideBalanceOnOpenSubtitle =>
      'Il saldo sarà oscurato di default in Home';

  @override
  String get timezoneLabel => 'Fuso orario';

  @override
  String get languageLabel => 'Lingua';

  @override
  String exportSavedMessage(String path) {
    return 'Esportazione salvata in $path';
  }

  @override
  String get deleteAccountConfirmTitle => 'Eliminare l\'account?';

  @override
  String get deleteAccountConfirmMessage =>
      'Questa azione è irreversibile. Il tuo profilo verrà rimosso; le operazioni registrate restano solo a fini contabili.';

  @override
  String get confirmPasswordDialogTitle => 'Conferma la password';

  @override
  String get currentPasswordOptionalGoogleLabel =>
      'Password attuale (vuota se solo Google)';

  @override
  String get deleteAccountAction => 'Elimina account';

  @override
  String get exportDataSectionTitle => 'Esporta i tuoi dati';

  @override
  String get exportDataDescription =>
      'CSV per le operazioni, JSON per profilo, portafoglio, categorie, modelli e operazioni.';

  @override
  String get exportCsvAction => 'Esporta CSV';

  @override
  String get exportJsonAction => 'Esporta JSON';

  @override
  String get dangerZoneTitle => 'Zona pericolosa';

  @override
  String get accountProfileScreenTitle => 'Profilo';

  @override
  String get profileUpdatedMessage => 'Profilo aggiornato.';

  @override
  String get verificationEmailSentMessage => 'Email di verifica inviata.';

  @override
  String get firstNameLabel => 'Nome';

  @override
  String get lastNameLabel => 'Cognome';

  @override
  String get usernameLabel => 'Username';

  @override
  String get emailLabel => 'Email';

  @override
  String get resendVerificationTooltip => 'Invia di nuovo la verifica';

  @override
  String get emailNotVerifiedHint =>
      'Email non verificata. Tocca l\'icona per reinviare il link.';

  @override
  String get currentPasswordLabel => 'Password attuale';

  @override
  String get googleLinkedSuccessMessage => 'Google collegato con successo.';

  @override
  String get unlinkGoogleConfirmTitle => 'Scollegare Google?';

  @override
  String get unlinkGoogleConfirmMessage =>
      'Potrai comunque accedere con la tua password.';

  @override
  String get unlinkGoogleAction => 'Scollega';

  @override
  String get googleUnlinkedSuccessMessage => 'Google scollegato.';

  @override
  String get notLinkedLabel => 'Non collegato';

  @override
  String get linkAction => 'Collega';

  @override
  String get linkedNeverUsedLabel => 'Collegato, mai utilizzato';

  @override
  String lastUsedLabel(String date) {
    return 'Ultimo utilizzo: $date';
  }

  @override
  String currentBalanceLabel(String balance) {
    return 'Saldo attuale: $balance';
  }

  @override
  String get reasonOptionalLabel => 'Motivo (opzionale)';

  @override
  String get saveAdjustmentAction => 'Salva rettifica';

  @override
  String get reportTrendTitle => 'Andamento';

  @override
  String get showChartTooltip => 'Mostra grafico';

  @override
  String get showTableTooltip => 'Mostra tabella (accessibile)';

  @override
  String get noDataForPeriod => 'Nessun dato per il periodo selezionato.';

  @override
  String get periodColumnLabel => 'Periodo';

  @override
  String get creditsColumnLabel => 'Entrate';

  @override
  String get debitsColumnLabel => 'Uscite';

  @override
  String get balanceColumnLabel => 'Saldo';

  @override
  String get reportBreakdownTitle => 'Ripartizione';

  @override
  String get groupByTitleOption => 'Per titolo';

  @override
  String get groupByCategoryOption => 'Per categoria';

  @override
  String get noTransactionsForView => 'Nessuna operazione per questa vista.';

  @override
  String transactionCountLabel(int count) {
    return '$count operazioni';
  }

  @override
  String get monthlyComparisonTitle => 'Confronto mensile';

  @override
  String get monthColumnLabel => 'Mese';

  @override
  String get netColumnLabel => 'Netto';

  @override
  String monthDetailSnackbar(
    String month,
    String credits,
    String debits,
    String net,
  ) {
    return '$month: entrate $credits, uscite $debits, netto $net';
  }

  @override
  String get filtersTitle => 'Filtri';

  @override
  String get typeLabel => 'Tipo';

  @override
  String get titleFieldLabel => 'Titolo';

  @override
  String get minAmountLabel => 'Importo minimo';

  @override
  String get maxAmountLabel => 'Importo massimo';

  @override
  String get startDateLabel => 'Data iniziale';

  @override
  String get endDateLabel => 'Data finale';

  @override
  String get anyLabel => 'Qualsiasi';

  @override
  String get allCategoriesLabel => 'Tutte le categorie';

  @override
  String get resetAction => 'Azzera';

  @override
  String get applyAction => 'Applica';

  @override
  String get typeFilterAll => 'Tutte';

  @override
  String get typeFilterAdjustments => 'Rettifiche';

  @override
  String get categoryPickerTitle => 'Categoria';

  @override
  String get categoriesLoadError => 'Impossibile caricare le categorie.';

  @override
  String get noCategoryLabel => 'Nessuna categoria';

  @override
  String get createAndSelectAction => 'Crea e seleziona';

  @override
  String get newCategoryAction => 'Nuova categoria';

  @override
  String get newCategoryNameLabel => 'Nome nuova categoria';

  @override
  String get createCategoryError => 'Impossibile creare la categoria. Riprova.';

  @override
  String get descriptionOptionalLabel => 'Descrizione (facoltativa)';

  @override
  String get loginAction => 'Accedi';

  @override
  String get forgotPasswordAction => 'Password dimenticata?';

  @override
  String get usernameOrEmailLabel => 'Username o email';

  @override
  String get passwordLabel => 'Password';

  @override
  String get orDividerLabel => 'oppure';

  @override
  String get continueWithGoogleAction => 'Continua con Google';

  @override
  String get createAccountAction => 'Crea un account';

  @override
  String get confirmRegistrationAction => 'Conferma registrazione';

  @override
  String get nextAction => 'Avanti';

  @override
  String get backAction => 'Indietro';

  @override
  String get accountStepTitle => 'Account';

  @override
  String get confirmPasswordLabel => 'Conferma password';

  @override
  String get profileStepTitle => 'Profilo';

  @override
  String get backgroundColorLabel => 'Colore sfondo';

  @override
  String get walletStepTitle => 'Portafoglio';

  @override
  String get initialBalanceLabel => 'Saldo iniziale (EUR)';

  @override
  String get acceptTermsLabel =>
      'Accetto i termini di servizio e la privacy policy';

  @override
  String registrationSummaryLabel(
    Object balance,
    Object firstName,
    Object lastName,
    Object username,
  ) {
    return 'Riepilogo: $firstName $lastName, @$username, saldo iniziale $balance';
  }

  @override
  String get completeRegistrationScreenTitle => 'Completa la registrazione';

  @override
  String get backToLoginAction => 'Torna al login';

  @override
  String googleSignInConfirmedMessage(String email) {
    return 'Accesso confermato con Google come $email.';
  }

  @override
  String get localPasswordOptionalHint =>
      'Password locale (facoltativa: senza, potrai accedere solo con Google)';

  @override
  String get completeRegistrationAction => 'Completa registrazione';

  @override
  String get forgotPasswordScreenTitle => 'Password dimenticata';

  @override
  String get forgotPasswordSuccessMessage =>
      'Se l\'indirizzo è registrato, riceverai a breve un\'email con le istruzioni per reimpostare la password.';

  @override
  String get forgotPasswordInstructionsMessage =>
      'Inserisci la tua email: ti invieremo le istruzioni per reimpostare la password.';

  @override
  String get sendAction => 'Invia';

  @override
  String get transactionDetailScreenTitle => 'Dettaglio operazione';

  @override
  String get editTooltip => 'Modifica';

  @override
  String get deleteTooltip => 'Elimina';

  @override
  String get commonDelete => 'Elimina';

  @override
  String get deleteTransactionConfirmTitle => 'Eliminare questa operazione?';

  @override
  String get deleteTransactionConfirmMessage =>
      'Il saldo verrà aggiornato di conseguenza.';

  @override
  String get openingBalanceKindLabel => 'Saldo iniziale';

  @override
  String get balanceAdjustmentKindLabel => 'Rettifica saldo';

  @override
  String get manualKindLabel => 'Manuale';

  @override
  String get categoryLabel => 'Categoria';

  @override
  String get sourceLabel => 'Origine';

  @override
  String get dateAndTimeLabel => 'Data e ora';

  @override
  String get descriptionLabel => 'Descrizione';

  @override
  String get createdLabel => 'Creata il';

  @override
  String get lastModifiedLabel => 'Ultima modifica';
}
