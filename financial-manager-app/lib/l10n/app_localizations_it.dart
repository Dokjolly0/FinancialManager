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
  String get errorCodeWalletNotFound => 'Portafoglio non trovato.';

  @override
  String get errorCodeAiDisabled =>
      'L\'Analisi AI non è attiva su questo server.';

  @override
  String get errorCodeAiNotConfigured =>
      'Configura prima fornitore, chiave API e modello.';

  @override
  String get errorCodeAiConsentRequired =>
      'Per continuare accetta l\'informativa sull\'Analisi AI.';

  @override
  String get errorCodeAiDataChanged =>
      'I tuoi dati sono cambiati dopo l\'anteprima: controllala di nuovo.';

  @override
  String get errorCodeAiStreamInProgress =>
      'C\'è già un\'analisi in corso: attendi che finisca o interrompila.';

  @override
  String get errorCodeAiPromptTooLarge =>
      'Troppi dati per una sola analisi: scegli un periodo più breve, meno portafogli o meno movimenti.';

  @override
  String get errorCodeAiFollowupLimit =>
      'Hai raggiunto il numero massimo di domande per questa analisi: avviane una nuova.';

  @override
  String get errorCodeAiAnalysisExists =>
      'Questa analisi è già stata avviata: la trovi nella cronologia.';

  @override
  String get errorCodeAiAnalysisNotReady =>
      'Le domande di approfondimento richiedono un report completato.';

  @override
  String get errorCodeAiKeyUnreadable =>
      'La chiave API salvata non è più leggibile: inseriscila di nuovo.';

  @override
  String get errorCodeAiStreamInterrupted =>
      'L\'analisi si è interrotta prima di terminare.';

  @override
  String get errorCodeAiAnswerTooLong =>
      'La risposta era troppo lunga ed è stata troncata.';

  @override
  String get errorCodeAiProviderError =>
      'Il fornitore AI ha restituito un errore.';

  @override
  String get errorCodeAiProviderInvalidKey =>
      'La chiave API non è valida o non ha i permessi necessari.';

  @override
  String get errorCodeAiProviderRateLimited =>
      'Il fornitore AI sta limitando le richieste: riprova tra poco.';

  @override
  String get errorCodeAiProviderQuotaExceeded =>
      'Credito o quota del fornitore AI esauriti: controlla il tuo account presso il fornitore.';

  @override
  String get errorCodeAiProviderContextTooLong =>
      'Il modello non riesce a leggere così tanti dati: riduci il periodo o i movimenti inclusi.';

  @override
  String get errorCodeAiProviderModelNotFound =>
      'Il modello scelto non esiste o non è disponibile per la tua chiave.';

  @override
  String get errorCodeAiProviderContentBlocked =>
      'Il fornitore AI ha bloccato la risposta per i suoi filtri di sicurezza.';

  @override
  String get errorCodeAiProviderUnavailable =>
      'Il fornitore AI è momentaneamente sovraccarico o non disponibile.';

  @override
  String get errorCodeAiProviderTimeout =>
      'Il fornitore AI ha impiegato troppo tempo e l\'analisi è stata interrotta.';

  @override
  String get errorCodeAiProviderUnreachable =>
      'Impossibile raggiungere il fornitore AI.';

  @override
  String get errorCodeAiProviderInvalid => 'Fornitore non supportato.';

  @override
  String get errorCodeAiBaseUrlInvalid =>
      'Inserisci un indirizzo https valido, senza credenziali né parametri.';

  @override
  String get errorCodeAiBaseUrlNotAllowed =>
      'Questo server non può collegarsi a indirizzi privati o locali.';

  @override
  String get errorCodeAiTextTooLong => 'Il testo è troppo lungo.';

  @override
  String get errorCodeValueOutOfRange => 'Valore fuori dai limiti consentiti.';

  @override
  String get errorCodeInvalidValue => 'Valore non valido.';

  @override
  String get errorCodeAiConsentVersionInvalid =>
      'L\'informativa è stata aggiornata: rileggila e accettala di nuovo.';

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
  String get errorCodeWalletNotMealVoucher =>
      'Disponibile solo per i portafogli buoni pasto.';

  @override
  String get errorCodeWalletIsMealVoucher =>
      'Non disponibile per i portafogli buoni pasto: usa le operazioni dedicate ai buoni.';

  @override
  String get errorCodeVoucherInsufficientBalance =>
      'Non ci sono abbastanza buoni disponibili.';

  @override
  String get errorCodeVoucherLotAlreadyUsed =>
      'Alcuni di questi buoni sono già stati spesi o rimossi.';

  @override
  String get errorCodeVoucherLotAlreadyExpired =>
      'Questo lotto di buoni è già scaduto e non può più essere modificato.';

  @override
  String get errorCodeVoucherAutoAdjustmentNotDeletable =>
      'Le rettifiche automatiche per buoni scaduti non possono essere eliminate.';

  @override
  String get errorCodeOtherWalletRequired =>
      'Seleziona il portafoglio con cui hai pagato la differenza.';

  @override
  String get errorCodeOtherWalletNotAllowed =>
      'I buoni scelti coprono già l\'intera spesa: non serve un altro portafoglio.';

  @override
  String get errorCodeSameAsVoucherWallet =>
      'Il portafoglio della differenza deve essere diverso da quello dei buoni.';

  @override
  String get errorCodeInvalidMonth => 'Mese non valido.';

  @override
  String get errorCodeInvalidDay => 'Giorno non valido.';

  @override
  String get errorCodeNotAllowedForWalletType =>
      'Non consentito per questo tipo di portafoglio.';

  @override
  String get errorCodePurposeLengthInvalid =>
      'Lo scopo può contenere al massimo 280 caratteri.';

  @override
  String get errorCodeLinkTargetNotFound =>
      'Transazione da collegare non trovata.';

  @override
  String get errorCodeLinkTargetNotLinkable =>
      'Questa transazione non può essere collegata.';

  @override
  String get errorCodeNotInPaymentGroup =>
      'Questa transazione non è collegata ad altre.';

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
  String get accountWalletsMenuTitle => 'Portafogli';

  @override
  String get accountWalletsMenuSubtitle =>
      'Gestisci i tuoi conti e il contante';

  @override
  String get walletsScreenTitle => 'Portafogli';

  @override
  String get walletsTotalBalanceLabel => 'Saldo totale';

  @override
  String get addWalletAction => 'Nuovo portafoglio';

  @override
  String get walletsLoadError => 'Impossibile caricare i portafogli.';

  @override
  String get walletsEmptyStateMessage => 'Nessun portafoglio attivo.';

  @override
  String get transferAction => 'Trasferisci';

  @override
  String get newWalletScreenTitle => 'Nuovo portafoglio';

  @override
  String get editWalletScreenTitle => 'Modifica portafoglio';

  @override
  String get walletNameLabel => 'Nome';

  @override
  String get walletPurposeLabel => 'Scopo (facoltativo)';

  @override
  String get walletPurposeHint =>
      'Es. spese quotidiane, fondo emergenze, risparmi per le vacanze';

  @override
  String get walletPurposeHelper =>
      'Aiuta l\'Analisi AI a capire a cosa serve questo portafoglio.';

  @override
  String get walletTypeLabel => 'Tipo';

  @override
  String get walletTypeCash => 'Contante';

  @override
  String get walletTypeBank => 'Conto bancario';

  @override
  String get walletTypeOther => 'Altro';

  @override
  String get walletIconLabel => 'Icona';

  @override
  String get walletColorLabel => 'Colore';

  @override
  String get saveWalletAction => 'Salva portafoglio';

  @override
  String get createWalletError => 'Impossibile creare il portafoglio.';

  @override
  String get updateWalletError => 'Impossibile salvare il portafoglio.';

  @override
  String get archiveWalletAction => 'Archivia portafoglio';

  @override
  String get archiveWalletConfirmTitle => 'Archiviare questo portafoglio?';

  @override
  String get archiveWalletConfirmMessage =>
      'Il portafoglio verrà archiviato e non sarà più selezionabile per nuove operazioni; la sua cronologia resterà nei report.';

  @override
  String archiveWalletConfirmMessageWithBalance(String balance) {
    return 'Il portafoglio ha ancora un saldo di $balance. Verrà archiviato e non sarà più selezionabile per nuove operazioni; la sua cronologia resterà nei report.';
  }

  @override
  String get archiveWalletError => 'Impossibile archiviare il portafoglio.';

  @override
  String get walletDenominationsAction => 'Banconote e monete';

  @override
  String get walletDenominationsScreenTitle => 'Banconote e monete';

  @override
  String get denominationCountLabel => 'Quantità';

  @override
  String get saveDenominationsAction => 'Salva conteggio';

  @override
  String get denominationsLoadError =>
      'Impossibile caricare le banconote e monete.';

  @override
  String get walletPickerTitle => 'Scegli portafoglio';

  @override
  String get selectWalletPlaceholder => 'Seleziona un portafoglio';

  @override
  String get transferSheetTitle => 'Trasferimento tra portafogli';

  @override
  String get transferSourceWalletLabel => 'Da';

  @override
  String get transferDestinationWalletLabel => 'A';

  @override
  String get transferAmountLabel => 'Importo';

  @override
  String get transferNoteLabel => 'Nota (opzionale)';

  @override
  String get submitTransferAction => 'Trasferisci';

  @override
  String get transferSameWalletError =>
      'Il portafoglio di destinazione deve essere diverso da quello di partenza.';

  @override
  String get editTransferSheetTitle => 'Modifica trasferimento';

  @override
  String get saveTransferAction => 'Salva trasferimento';

  @override
  String get walletBadgeArchived => 'Archiviato';

  @override
  String get allWalletsLabel => 'Tutti i portafogli';

  @override
  String get walletTypeMealVoucher => 'Buoni pasto';

  @override
  String get voucherUnitValueLabel => 'Valore del buono';

  @override
  String get voucherExpiryPolicyLabel => 'Scadenza dei buoni';

  @override
  String get voucherExpiryCutoffMonthLabel => 'Fino al mese di';

  @override
  String get voucherExpiryMonthLabel => 'Mese di scadenza';

  @override
  String get voucherExpiryDayLabel => 'Giorno di scadenza';

  @override
  String get voucherInitialQuantityLabel => 'Numero di buoni iniziali';

  @override
  String get voucherLoadedAtLabel => 'Data di carico';

  @override
  String get voucherLotsAction => 'Buoni pasto';

  @override
  String get voucherLotsScreenTitle => 'Buoni pasto';

  @override
  String get voucherLotsLoadError => 'Impossibile caricare i buoni pasto.';

  @override
  String get voucherActiveSectionTitle => 'Attivi';

  @override
  String get voucherActiveEmptyMessage => 'Nessun buono attivo.';

  @override
  String get voucherExpiringSoonSectionTitle => 'In scadenza a breve';

  @override
  String get voucherExpiredSectionTitle => 'Scaduti';

  @override
  String get voucherExpiredEmptyMessage => 'Nessun buono scaduto.';

  @override
  String voucherLotQuantityLabel(int count) {
    return '$count buoni';
  }

  @override
  String voucherLotExpiresOnLabel(String date) {
    return 'Scade il $date';
  }

  @override
  String voucherLotExpiredOnLabel(String date) {
    return 'Scaduto il $date';
  }

  @override
  String voucherExpiringSoonBadge(int count) {
    return '$count buoni in scadenza';
  }

  @override
  String get addVouchersAction => 'Aggiungi buoni';

  @override
  String get removeVouchersAction => 'Rimuovi buoni';

  @override
  String get addVouchersSheetTitle => 'Aggiungi buoni';

  @override
  String get removeVouchersSheetTitle => 'Rimuovi buoni';

  @override
  String get voucherQuantityLabel => 'Numero di buoni';

  @override
  String get voucherExpenseAction => 'Spesa con buoni pasto';

  @override
  String get voucherExpenseSheetTitle => 'Spesa con buoni pasto';

  @override
  String get editVoucherExpenseSheetTitle => 'Modifica spesa con buoni pasto';

  @override
  String get voucherWalletLabel => 'Portafoglio buoni';

  @override
  String get voucherOtherWalletLabel => 'Pagato con';

  @override
  String get voucherOtherWalletRequiredError =>
      'Seleziona il portafoglio con cui hai pagato la differenza.';

  @override
  String get voucherTotalExpenseLabel => 'Totale della spesa';

  @override
  String voucherShortfallLabel(String amount) {
    return 'Differenza da pagare: $amount';
  }

  @override
  String voucherSuggestedQuantityHelper(int count) {
    return 'Minimo consigliato: $count';
  }

  @override
  String get submitVoucherExpenseAction => 'Registra spesa';

  @override
  String get saveVoucherExpenseAction => 'Salva spesa';

  @override
  String get noImageSelectedLabel => 'Nessuna immagine';

  @override
  String get imageSelectedLabel => 'Immagine selezionata';

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
  String get titleOrDescriptionFilterLabel => 'Titolo o descrizione';

  @override
  String get historySearchHint => 'Cerca per titolo o descrizione';

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
  String get typeFilterTransfers => 'Trasferimenti';

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
  String get categorySearchHint => 'Cerca categoria';

  @override
  String get categorySearchNoResults => 'Nessuna categoria trovata.';

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
  String get transferKindLabel => 'Trasferimento';

  @override
  String get walletLabel => 'Portafoglio';

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

  @override
  String get editOpeningBalanceSheetTitle => 'Modifica saldo iniziale';

  @override
  String get editOpeningBalanceHint =>
      'È il punto di partenza del portafoglio, non una rettifica: modificarlo cambia anche report e grafici passati.';

  @override
  String get saveOpeningBalanceAction => 'Salva saldo iniziale';

  @override
  String get addLinkedPaymentTooltip => 'Aggiungi pagamento collegato';

  @override
  String get linkedPaymentsSectionTitle => 'Pagamenti collegati';

  @override
  String get linkedPaymentsTotalLabel => 'Totale speso';

  @override
  String get linkedPaymentsCurrentLabel => 'Stai visualizzando';

  @override
  String get linkedPaymentsEmptyStateMessage =>
      'Nessun pagamento collegato ancora.';

  @override
  String linkedPaymentsMemberCountLabel(int count) {
    return '$count pagamenti';
  }

  @override
  String get mediaPickerRecentTab => 'Recenti';

  @override
  String get mediaPickerLibraryTab => 'Libreria';

  @override
  String get mediaPickerSearchTab => 'Cerca';

  @override
  String get mediaPickerUploadTab => 'Carica';

  @override
  String get mediaLoadErrorMessage => 'Impossibile caricare le immagini.';

  @override
  String get mediaEmptyStateMessage => 'Nessuna immagine disponibile.';

  @override
  String get mediaUntitledLabel => 'Senza titolo';

  @override
  String get mediaLibrarySearchHint => 'Cerca nella libreria';

  @override
  String get mediaSearchHint => 'Cerca immagini';

  @override
  String get mediaSearchMinCharsMessage =>
      'Digita almeno 2 caratteri per cercare.';

  @override
  String get mediaSearchNoResultsMessage => 'Nessun risultato.';

  @override
  String get mediaSearchUnavailableMessage =>
      'Ricerca non disponibile al momento.';

  @override
  String get mediaSelectFailedMessage =>
      'Impossibile selezionare questa immagine.';

  @override
  String get mediaCropScreenTitle => 'Ritaglia immagine';

  @override
  String get mediaCameraAction => 'Fotocamera';

  @override
  String get mediaGalleryAction => 'Galleria';

  @override
  String get mediaUploadFailedMessage => 'Caricamento non riuscito. Riprova.';

  @override
  String get mediaRenameDialogTitle => 'Rinomina immagine';

  @override
  String get mediaNameLabel => 'Nome';

  @override
  String get mediaRenameFailedMessage => 'Impossibile rinominare l\'immagine.';

  @override
  String get aiAssistantMenuTitle => 'Assistente AI';

  @override
  String get aiAssistantMenuSubtitle =>
      'Analizza le tue finanze con un modello AI';

  @override
  String get aiAssistantTitle => 'Assistente AI';

  @override
  String get aiUnavailableTitle => 'Analisi AI non disponibile';

  @override
  String get aiUnavailableBody =>
      'Questo server non ha attivato l\'Analisi AI. Chi gestisce il server può abilitarla impostando AI_KEY_ENCRYPTION_KEY.';

  @override
  String get aiSetupTitle => 'Prepara la tua prima analisi';

  @override
  String get aiSetupDoneTitle => 'Tutto pronto';

  @override
  String aiSetupProgress(int done, int total) {
    return '$done di $total passaggi completati';
  }

  @override
  String get aiSetupOptional => 'facoltativo';

  @override
  String get aiSetupStepProvider => 'Fornitore, chiave e modello';

  @override
  String get aiSetupStepProviderHint =>
      'Scegli il servizio AI e inserisci la tua chiave API';

  @override
  String get aiSetupStepContext => 'Contesto personale';

  @override
  String get aiSetupStepContextHint =>
      'Obiettivi e situazione, per consigli su misura';

  @override
  String get aiSetupStepPurposes => 'Scopo dei portafogli';

  @override
  String get aiSetupStepPurposesHint => 'A cosa serve ciascun portafoglio';

  @override
  String get aiSetupStepFirstAnalysis => 'Prima analisi';

  @override
  String get aiSetupStepFirstAnalysisHint =>
      'Dalla sezione Report, scheda Analisi AI';

  @override
  String get aiProviderMenuTitle => 'Fornitore e chiave API';

  @override
  String get aiProviderMenuNotConfigured => 'Non configurato';

  @override
  String get aiContextMenuTitle => 'Contesto personale';

  @override
  String get aiContextMenuFilled => 'Compilato';

  @override
  String get aiContextMenuEmpty => 'Non ancora compilato';

  @override
  String get aiWalletPurposesMenuTitle => 'Scopo dei portafogli';

  @override
  String aiWalletPurposesProgress(int done, int total) {
    return '$done di $total portafogli con uno scopo';
  }

  @override
  String get aiConsentMenuTitle => 'Privacy e consenso';

  @override
  String get aiConsentMenuPending => 'Da accettare prima della prima analisi';

  @override
  String get aiConsentMenuAccepted => 'Accettato';

  @override
  String get aiConsentRevokeAction => 'Revoca';

  @override
  String get aiConsentRevokeConfirmTitle => 'Revocare il consenso?';

  @override
  String get aiConsentRevokeConfirmMessage =>
      'Non potrai avviare analisi finché non lo accetterai di nuovo. Le analisi salvate restano nella cronologia.';

  @override
  String get aiConsentTitle => 'Prima di iniziare';

  @override
  String get aiConsentIntro =>
      'L\'Analisi AI invia un riepilogo dei tuoi dati al fornitore AI che scegli tu, usando la tua chiave API. Prima di ogni invio vedrai esattamente cosa viene inviato.';

  @override
  String get aiConsentSentTitle => 'Cosa viene inviato';

  @override
  String get aiConsentSentAggregates =>
      'Totali, andamento mensile, categorie e voci principali del periodo scelto';

  @override
  String get aiConsentSentWallets =>
      'Nome, tipo, scopo e saldo dei portafogli inclusi';

  @override
  String get aiConsentSentTransactions =>
      'Solo se lo attivi: l\'elenco dei movimenti, anche con titoli anonimizzati';

  @override
  String get aiConsentSentContext =>
      'Solo se lo attivi: il contesto personale che hai scritto';

  @override
  String get aiConsentNeverTitle => 'Cosa non viene mai inviato';

  @override
  String get aiConsentNeverBody =>
      'Email, nome, nome utente, identificativi dell\'account e immagini';

  @override
  String get aiConsentKeyTitle => 'La tua chiave API';

  @override
  String get aiConsentKeyBody =>
      'Resta cifrata sul server e non viene mai mostrata di nuovo né esportata';

  @override
  String get aiConsentProviderTitle => 'Il fornitore';

  @override
  String get aiConsentProviderBody =>
      'Tratta i dati secondo le sue condizioni: verifica per quanto tempo conserva le richieste e se le usa per addestrare i modelli';

  @override
  String get aiConsentRevokeTitle => 'Puoi cambiare idea';

  @override
  String get aiConsentRevokeBody =>
      'Revoca il consenso e cancella le analisi in qualsiasi momento da Assistente AI';

  @override
  String get aiConsentAccept => 'Ho capito, accetto';

  @override
  String get aiConsentDecline => 'Non ora';

  @override
  String get aiProviderLabel => 'Fornitore';

  @override
  String get aiProviderCompatible =>
      'Compatibile OpenAI (Mistral, Groq, OpenRouter, Ollama…)';

  @override
  String get aiProviderHintAnthropic =>
      'Crea una chiave su console.anthropic.com → API keys.';

  @override
  String get aiProviderHintOpenai =>
      'Crea una chiave su platform.openai.com → API keys.';

  @override
  String get aiProviderHintGemini =>
      'Crea una chiave su aistudio.google.com → Get API key.';

  @override
  String get aiProviderHintCompatible =>
      'Per qualsiasi servizio che espone l\'API di OpenAI: inserisci il suo indirizzo, di solito terminante in /v1.';

  @override
  String get aiBaseUrlLabel => 'Indirizzo del servizio (base URL)';

  @override
  String get aiBaseUrlHelper =>
      'Indirizzi privati o locali (es. Ollama in casa) funzionano solo se chi gestisce il server lo ha permesso.';

  @override
  String get aiApiKeyLabel => 'Chiave API';

  @override
  String get aiApiKeyOptionalLabel => 'Chiave API (se richiesta)';

  @override
  String get aiApiKeyHelper =>
      'Viene cifrata sul server: dopo il salvataggio vedrai solo le ultime cifre.';

  @override
  String get aiApiKeyWillBeRemoved =>
      'La chiave salvata verrà rimossa al salvataggio.';

  @override
  String aiApiKeyStored(String hint) {
    return 'Chiave salvata $hint';
  }

  @override
  String get aiApiKeyReplace => 'Sostituisci';

  @override
  String get aiApiKeyRemove => 'Rimuovi';

  @override
  String get aiApiKeyShow => 'Mostra chiave';

  @override
  String get aiApiKeyHide => 'Nascondi chiave';

  @override
  String get aiModelLabel => 'Modello';

  @override
  String get aiModelHelper =>
      'Premi «Carica modelli» per sceglierlo dall\'elenco del fornitore, oppure scrivine il nome.';

  @override
  String aiModelsLoaded(int count) {
    return '$count modelli disponibili';
  }

  @override
  String get aiModelsNoneFound =>
      'Il fornitore non ha restituito modelli: scrivi il nome a mano.';

  @override
  String get aiLoadModels => 'Carica modelli';

  @override
  String get aiTestConnection => 'Verifica connessione';

  @override
  String aiTestOk(String model, int ms) {
    return 'Funziona: $model ha risposto in $ms ms.';
  }

  @override
  String aiTestOkKeyOnly(int ms) {
    return 'Chiave valida (risposta in $ms ms). Scegli un modello per verificarlo.';
  }

  @override
  String get aiLastTestOk => 'Ultima verifica riuscita.';

  @override
  String get aiLastTestFailed => 'Ultima verifica non riuscita.';

  @override
  String get aiAdvancedSettings => 'Impostazioni avanzate';

  @override
  String get aiMaxOutputTokensLabel =>
      'Lunghezza massima della risposta (token)';

  @override
  String aiMaxOutputTokensHelper(int min, int max) {
    return 'Tra $min e $max. Più è alto, più il report può essere lungo e costare.';
  }

  @override
  String get aiPricesTitle => 'Prezzi (facoltativi)';

  @override
  String get aiPricesHelper =>
      'Prezzo per milione di token del tuo modello, nella valuta del fornitore: serve solo per stimare il costo.';

  @override
  String get aiInputPriceLabel => 'Input';

  @override
  String get aiOutputPriceLabel => 'Output';

  @override
  String get aiDefaultIncludeTransactions =>
      'Includi i singoli movimenti di default';

  @override
  String get aiDefaultIncludeTransactionsHint =>
      'Analisi più precise, ma più dati inviati e più token.';

  @override
  String get aiDefaultAnonymizeTitles => 'Anonimizza i titoli di default';

  @override
  String get aiDefaultAnonymizeTitlesHint =>
      'I nomi dei movimenti diventano «Voce 1», «Voce 2»…';

  @override
  String get aiSaveSettings => 'Salva';

  @override
  String get aiForgetProviderTitle => 'Dimenticare questo fornitore?';

  @override
  String get aiForgetProviderMessage =>
      'La chiave API salvata viene eliminata dal server.';

  @override
  String get aiForgetProviderAction => 'Elimina chiave e fornitore';

  @override
  String get aiContextIntro =>
      'Queste informazioni aiutano l\'AI a darti consigli adatti alla tua situazione. Sono tutte facoltative e le invii solo se includi il contesto personale in un\'analisi.';

  @override
  String get aiNotSpecified => 'Non specificato';

  @override
  String get aiHouseholdLabel => 'Persone nel nucleo familiare';

  @override
  String aiHouseholdValue(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count persone',
      one: '1 persona',
    );
    return '$_temp0';
  }

  @override
  String get aiHouseholdLess => 'Una persona in meno';

  @override
  String get aiHouseholdMore => 'Una persona in più';

  @override
  String get aiIncomeTypeLabel => 'Tipo di reddito';

  @override
  String get aiIncomeEmployee => 'Lavoro dipendente';

  @override
  String get aiIncomeSelfEmployed => 'Lavoro autonomo';

  @override
  String get aiIncomeStudent => 'Studente';

  @override
  String get aiIncomeRetired => 'Pensione';

  @override
  String get aiIncomeUnemployed => 'Senza reddito da lavoro';

  @override
  String get aiIncomeMixed => 'Misto';

  @override
  String get aiIncomeOther => 'Altro';

  @override
  String get aiAboutMeLabel => 'Su di me';

  @override
  String get aiAboutMeHint =>
      'Es. vivo in affitto a Milano, ho un\'auto, lo stipendio arriva il 27';

  @override
  String get aiGoalsLabel => 'Obiettivi';

  @override
  String get aiGoalsHint =>
      'Es. mettere da parte 5.000 € entro giugno, ridurre le spese per mangiare fuori';

  @override
  String get aiIgnoreLabel => 'Cose da ignorare o da interpretare';

  @override
  String get aiIgnoreHint =>
      'Es. il bonifico a Marco è un prestito che mi restituisce; a luglio ho pagato l\'assicurazione annuale';

  @override
  String get aiResponseStyleLabel => 'Stile delle risposte';

  @override
  String get aiStyleDefault => 'Standard';

  @override
  String get aiStyleConcise => 'Conciso';

  @override
  String get aiStyleDetailed => 'Dettagliato';

  @override
  String get aiContextPrivacyNote =>
      'Non scrivere qui dati come IBAN, codice fiscale o password: non servono all\'analisi.';

  @override
  String get aiSaveContext => 'Salva';

  @override
  String get aiWalletPurposesIntro =>
      'Indica a cosa serve ogni portafoglio: l\'AI potrà dirti se lo stai usando come previsto e suggerirti come organizzarti meglio.';

  @override
  String get aiWalletPurposesEmpty => 'Non hai ancora portafogli attivi.';

  @override
  String get aiWalletNoPurpose => 'Nessuno scopo';

  @override
  String get aiPurposeSuggestionDaily => 'Spese quotidiane';

  @override
  String get aiPurposeSuggestionSavings => 'Risparmi';

  @override
  String get aiPurposeSuggestionEmergency => 'Fondo emergenze';

  @override
  String get aiPurposeSuggestionHome => 'Spese di casa e bollette';

  @override
  String get aiPurposeSuggestionLeisure => 'Tempo libero e viaggi';

  @override
  String get aiSavePurpose => 'Salva scopo';
}
