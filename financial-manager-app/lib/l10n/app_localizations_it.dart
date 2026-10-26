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
  String get errorCodeCategoryNotHideable =>
      'Solo le categorie di sistema si possono nascondere: le tue puoi eliminarle.';

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
      'Tema, fuso orario, lingua, saldo, funzioni AI';

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
      'CSV per le operazioni, JSON per profilo, portafoglio, categorie, modelli, operazioni e analisi AI.';

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
  String get categorySortAlphabetical => 'A–Z';

  @override
  String get categorySortMostUsed => 'Più usate';

  @override
  String get categoriesScreenTitle => 'Categorie';

  @override
  String get categoriesMenuSubtitle => 'Ordina, modifica, elimina o nascondi';

  @override
  String get categoriesHiddenSection => 'Nascoste';

  @override
  String get categoriesHiddenHint =>
      'Non compaiono quando scegli una categoria, ma restano sulle transazioni già registrate.';

  @override
  String categoryUsageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count transazioni',
      one: '1 transazione',
      zero: 'Nessuna transazione',
    );
    return '$_temp0';
  }

  @override
  String get categorySystemLabel => 'Predefinita';

  @override
  String get editCategoryTitle => 'Modifica categoria';

  @override
  String get categoryNameLabel => 'Nome';

  @override
  String get categoryScopeLabel => 'Usata per';

  @override
  String get categoryScopeDebit => 'Uscite';

  @override
  String get categoryScopeCredit => 'Entrate';

  @override
  String get categoryScopeBoth => 'Entrambe';

  @override
  String get categoryColorLabel => 'Colore';

  @override
  String get categoryNoColor => 'Nessun colore';

  @override
  String get editCategoryAction => 'Modifica';

  @override
  String get hideCategoryAction => 'Nascondi';

  @override
  String get unhideCategoryAction => 'Mostra di nuovo';

  @override
  String get systemCategoryActionsHint =>
      'Le categorie predefinite non si possono modificare né eliminare, ma puoi nasconderle.';

  @override
  String deleteCategoryConfirmTitle(String name) {
    return 'Eliminare «$name»?';
  }

  @override
  String deleteCategoryInUseMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count transazioni usano questa categoria: resteranno senza categoria.',
      one: '1 transazione usa questa categoria: resterà senza categoria.',
    );
    return '$_temp0';
  }

  @override
  String get deleteCategoryUnusedMessage =>
      'Nessuna transazione usa questa categoria.';

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
  String get resetPasswordScreenTitle => 'Nuova password';

  @override
  String get resetPasswordInstructionsMessage =>
      'Scegli una nuova password per il tuo account.';

  @override
  String get newPasswordLabel => 'Nuova password';

  @override
  String get resetPasswordAction => 'Salva la password';

  @override
  String get resetPasswordSuccessMessage =>
      'Password aggiornata. Per sicurezza sono state chiuse tutte le sessioni: accedi con la nuova password.';

  @override
  String get requestNewLinkAction => 'Richiedi un nuovo link';

  @override
  String get verifyEmailScreenTitle => 'Conferma email';

  @override
  String get verifyEmailInProgressMessage =>
      'Conferma dell\'indirizzo email in corso…';

  @override
  String get verifyEmailSuccessMessage => 'Indirizzo email confermato.';

  @override
  String get goToAppAction => 'Vai all\'app';

  @override
  String get resendVerificationAction => 'Invia un nuovo link';

  @override
  String get verificationResentMessage =>
      'Ti abbiamo inviato un nuovo link: controlla la posta.';

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
      'L\'elenco dei movimenti: nelle analisi solo se lo attivi, anche con titoli anonimizzati; in \"Chiedi all\'assistente\" sempre, perché le risposte si basano sui singoli movimenti';

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

  @override
  String get aiNewAnalysisTitle => 'Nuova analisi AI';

  @override
  String get aiHistoryTitle => 'Cronologia analisi';

  @override
  String get aiHistoryMenuSubtitle => 'Rileggi, rinomina o elimina le analisi';

  @override
  String get aiNotReadyTitle => 'Configura prima l\'Analisi AI';

  @override
  String get aiNotReadyBody =>
      'Scegli un fornitore, inserisci la chiave API e un modello.';

  @override
  String get aiGoToSetup => 'Configura';

  @override
  String get aiWhatToAnalyze => 'Cosa vuoi analizzare';

  @override
  String get aiCustomQuestionLabel => 'La tua domanda';

  @override
  String get aiCustomQuestionHint =>
      'Es. quanto ho speso per mangiare fuori e come è cambiato nei mesi?';

  @override
  String get aiPeriodLabel => 'Periodo';

  @override
  String get aiPeriodLast30Days => 'Ultimi 30 giorni';

  @override
  String get aiPeriodLast12Months => 'Ultimi 12 mesi';

  @override
  String get aiPeriodCurrentMonth => 'Mese corrente';

  @override
  String get aiPeriodCurrentYear => 'Anno corrente';

  @override
  String get aiPeriodAllTime => 'Tutta la cronologia';

  @override
  String get aiPeriodCustom => 'Personalizzato';

  @override
  String aiPeriodUntil(String date) {
    return 'Fino al $date';
  }

  @override
  String get aiWalletsLabel => 'Portafogli';

  @override
  String get aiAllWallets => 'Tutti';

  @override
  String get aiDataToSend => 'Dati da inviare';

  @override
  String get aiDataToSendHint =>
      'Periodo, portafogli e totali vengono sempre inviati. Più dati scegli, più l\'analisi è ricca e più token consuma.';

  @override
  String get aiSectionMonthly => 'Andamento mensile';

  @override
  String get aiSectionCategories => 'Categorie';

  @override
  String get aiSectionTitles => 'Voci principali';

  @override
  String get aiSectionTransfers => 'Trasferimenti';

  @override
  String get aiSectionRecurring => 'Spese ricorrenti';

  @override
  String get aiSectionPersonalContext => 'Contesto personale';

  @override
  String get aiIncludeTransactions => 'Includi i singoli movimenti';

  @override
  String get aiIncludeTransactionsHint =>
      'Utile per le anomalie; invia data, importo, titolo e categoria dei movimenti più recenti.';

  @override
  String aiMaxTransactionsValue(int count) {
    return 'max $count';
  }

  @override
  String get aiIncludeAdjustments => 'Includi le rettifiche di saldo';

  @override
  String get aiIncludeAdjustmentsHint =>
      'Di solito correggono errori di registrazione: meglio lasciarle fuori.';

  @override
  String get aiPreviewAction => 'Anteprima';

  @override
  String get aiPreviewTitle => 'Anteprima';

  @override
  String get aiPreviewMissing =>
      'Nessuna anteprima: torna indietro e preparane una.';

  @override
  String aiPreviewSentTo(String provider, String model) {
    return 'Sarà inviato a $provider · $model';
  }

  @override
  String aiPreviewWallets(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count portafogli',
      one: '1 portafoglio',
    );
    return '$_temp0';
  }

  @override
  String get aiPreviewOnlyTotals => 'Solo periodo, portafogli e totali';

  @override
  String aiPreviewSections(String sections) {
    return 'Sezioni: $sections';
  }

  @override
  String get aiPreviewNoTransactions => 'Nessun movimento singolo';

  @override
  String aiPreviewTransactions(int count, int omitted) {
    return '$count movimenti singoli ($omitted meno recenti esclusi)';
  }

  @override
  String get aiPreviewAnonymized => 'Titoli dei movimenti anonimizzati';

  @override
  String get aiPreviewWithContext => 'Contesto personale incluso';

  @override
  String aiPreviewTokens(String tokens) {
    return '~$tokens token in input';
  }

  @override
  String aiPreviewCost(String cost) {
    return 'costo max ~$cost';
  }

  @override
  String get aiInstructionsLabel => 'Istruzioni';

  @override
  String get aiInstructionsHint =>
      'Puoi modificarle: è l\'unica parte del testo che decidi tu.';

  @override
  String get aiInstructionsRequired => 'Scrivi le istruzioni prima di inviare.';

  @override
  String get aiRestoreInstructions => 'Ripristina';

  @override
  String get aiSystemPromptLabel => 'Regole per il modello';

  @override
  String get aiSystemPromptHint =>
      'Fisse: formato del report, uso corretto dei dati, protezioni';

  @override
  String get aiDataBlockLabel => 'Dati inviati';

  @override
  String get aiDataBlockHint =>
      'Generati dal server dai tuoi movimenti, non modificabili';

  @override
  String get aiSendAction => 'Invia e analizza';

  @override
  String get aiAnalysisTitle => 'Analisi AI';

  @override
  String get aiDataSentTitle => 'Cosa è stato inviato';

  @override
  String get aiDataSentHint => 'Istruzioni e dati esattamente come inviati';

  @override
  String get aiCopyAction => 'Copia testo';

  @override
  String get aiShareAction => 'Condividi';

  @override
  String get aiCopied => 'Testo copiato';

  @override
  String get aiRefreshPreview => 'Aggiorna anteprima';

  @override
  String aiTokensUsed(String input, String output) {
    return '$input in / $output out token';
  }

  @override
  String aiCostValue(String cost) {
    return 'costo ~$cost';
  }

  @override
  String get aiThinking => 'Il modello sta scrivendo…';

  @override
  String get aiAnswerStopped => 'Interrotta: il testo qui sopra è parziale.';

  @override
  String get aiAnswerTruncated =>
      'Risposta troncata al limite di token: puoi alzarlo nelle impostazioni avanzate.';

  @override
  String get aiWaitForAnswer => 'Attendi la fine della risposta…';

  @override
  String get aiFollowUpUnavailable => 'Domande disponibili a report completato';

  @override
  String get aiFollowUpLimitReached => 'Limite di domande raggiunto';

  @override
  String aiAskFollowUpHint(int left) {
    return 'Fai una domanda ($left rimaste)';
  }

  @override
  String get aiStopAction => 'Interrompi';

  @override
  String get aiAskAction => 'Invia domanda';

  @override
  String get aiHistoryEmpty =>
      'Nessuna analisi ancora. Avviane una dalla sezione Report o fai una domanda in Chiedi all\'assistente.';

  @override
  String get aiDeleteAnalysisTitle => 'Eliminare l\'analisi?';

  @override
  String get aiDeleteAction => 'Elimina';

  @override
  String get aiDeleteAllAction => 'Elimina tutte';

  @override
  String get aiDeleteAllTitle => 'Eliminare tutte le analisi?';

  @override
  String get aiDeleteAllMessage =>
      'Report e conversazioni vengono eliminati definitivamente.';

  @override
  String get aiRenameAction => 'Rinomina';

  @override
  String get aiRenameTitle => 'Rinomina analisi';

  @override
  String get aiCancel => 'Annulla';

  @override
  String get aiReportsCardTitle => 'Analisi AI';

  @override
  String get aiReportsCardBody =>
      'Fatti spiegare i tuoi numeri: un report personalizzato e domande di approfondimento.';

  @override
  String get aiReportsCardSetupBody =>
      'Collega il tuo fornitore AI preferito per ottenere report personalizzati sulle tue finanze.';

  @override
  String get aiReportsCardStart => 'Analizza';

  @override
  String get aiHistoryAnalyzeAction => 'Analizza con AI i movimenti filtrati';

  @override
  String get aiHistoryAnalyzeAdjustments =>
      'L\'Analisi AI considera entrate e uscite: togli il filtro «rettifiche» per analizzare questi movimenti.';

  @override
  String get aiHistoryAnalyzeTransfers =>
      'I trasferimenti spostano denaro tra i tuoi portafogli e non vengono analizzati: togli il filtro «trasferimenti».';

  @override
  String get aiPeriodLastMonth => 'Mese scorso';

  @override
  String get aiPeriodLastQuarter => 'Trimestre scorso';

  @override
  String get aiDateFrom => 'Da';

  @override
  String get aiDateTo => 'A';

  @override
  String get aiDateFromEmpty => 'Dall\'inizio';

  @override
  String get aiDateToEmpty => 'Oggi';

  @override
  String get aiDateClear => 'Rimuovi data';

  @override
  String get aiFiltersTitle => 'Filtri';

  @override
  String get aiFiltersFromHistoryTitle => 'Filtri dalla Cronologia';

  @override
  String get aiFiltersHint =>
      'L\'analisi considera solo i movimenti che rispettano questi filtri. Saldi e trasferimenti non vengono inclusi.';

  @override
  String get aiFilterExpenses => 'Solo uscite';

  @override
  String get aiFilterIncome => 'Solo entrate';

  @override
  String aiFilterCategory(String name) {
    return 'Categoria: $name';
  }

  @override
  String aiFilterTitle(String text) {
    return 'Contiene «$text»';
  }

  @override
  String aiFilterAmountMin(String amount) {
    return 'Da $amount';
  }

  @override
  String aiFilterAmountMax(String amount) {
    return 'Fino a $amount';
  }

  @override
  String get aiProviderOnDevice => 'Sul dispositivo';

  @override
  String get errorCodeAiOnDeviceDisabled =>
      'L\'analisi sul dispositivo non è attiva su questo server.';

  @override
  String get errorCodeAiLocalConsentRequired =>
      'Per continuare accetta l\'informativa sull\'analisi sul dispositivo.';

  @override
  String get errorCodeAiAnalysisOnDevice =>
      'Questa analisi è stata scritta sul telefono: continuala da lì.';

  @override
  String get errorCodeAiAnalysisNotOnDevice =>
      'Questa analisi è stata scritta da un fornitore cloud.';

  @override
  String get errorCodeAiMessageFinished =>
      'Questa risposta era già stata salvata.';

  @override
  String get errorCodeAiLocalEngineError =>
      'Il modello sul telefono ha avuto un errore.';

  @override
  String get errorCodeAiLocalOutOfMemory =>
      'Memoria insufficiente: scegli un modello più piccolo o un contesto più corto.';

  @override
  String get errorCodeAiLocalContextTooLong =>
      'Il testo non entra nel contesto del modello: usa il profilo compatto, un contesto più grande o meno movimenti.';

  @override
  String get errorCodeAiLocalTimeout =>
      'Il telefono ha impiegato troppo tempo e la generazione è stata interrotta.';

  @override
  String get errorCodeAiLocalModelMissing =>
      'Nessun modello installato sul telefono: scaricane uno da Assistente AI.';

  @override
  String get errorCodeAiLocalInterrupted =>
      'La generazione sul telefono si è interrotta.';

  @override
  String get errorCodeAiLocalUnsupported =>
      'Questo dispositivo non può eseguire modelli in locale.';

  @override
  String get errorCodeAiLocalTooHot =>
      'Il telefono è troppo caldo per far girare il modello. Lascialo raffreddare qualche minuto e riprova.';

  @override
  String get aiCloudOnlyHereNote =>
      'Qui le analisi usano solo i fornitori cloud con la tua chiave API. Il modello sul telefono resta attivo nell\'app.';

  @override
  String get googleWebLinkDialogTitle =>
      'Scegli l\'account Google da collegare';

  @override
  String get mediaCropRotateLeft => 'Ruota a sinistra';

  @override
  String get mediaCropRotateRight => 'Ruota a destra';

  @override
  String get mediaCropConfirm => 'Ritaglia';

  @override
  String get aiDownloadAction => 'Scarica (.md)';

  @override
  String get aiModeCloud => 'Cloud';

  @override
  String get aiModeOnDevice => 'Sul dispositivo';

  @override
  String get aiLocalModeIntro =>
      'Il modello gira sul telefono: i tuoi dati non vanno a nessun fornitore AI esterno. Il server prepara i dati e salva report e domande nella cronologia, come per il cloud.';

  @override
  String get aiLocalModelsTitle => 'Modelli sul dispositivo';

  @override
  String get aiLocalRuntimeTitle => 'Impostazioni di esecuzione';

  @override
  String get aiLocalNoModel =>
      'Nessun modello attivo. Scaricane uno o importalo per usare l’analisi sul dispositivo.';

  @override
  String get aiLocalNoModelShort => 'Nessun modello installato';

  @override
  String get aiLocalChooseModel => 'Scegli un modello';

  @override
  String get aiLocalNotReadyBody =>
      'Per analizzare sul telefono serve un modello installato. Scaricane uno da Modelli sul dispositivo.';

  @override
  String get aiLocalConsentMenuTitle => 'Informativa sul dispositivo';

  @override
  String get aiLocalConsentIntro =>
      'Con l\'analisi sul dispositivo il modello AI gira sul tuo telefono. Prima di ogni analisi vedrai esattamente quali dati gli vengono dati.';

  @override
  String get aiLocalConsentWhereTitle => 'Dove vengono elaborati i dati';

  @override
  String get aiLocalConsentWhereBody =>
      'Sul telefono, senza connessione al modello: nessun fornitore AI esterno riceve i tuoi dati.';

  @override
  String get aiLocalConsentStoredTitle => 'Cosa resta sul server';

  @override
  String get aiLocalConsentStoredBody =>
      'Il server prepara il riepilogo dei dati e salva report e domande nella cronologia, così li ritrovi su ogni dispositivo.';

  @override
  String get aiLocalConsentMistakesTitle => 'Il modello può sbagliare';

  @override
  String get aiLocalConsentMistakesBody =>
      'I modelli che girano su un telefono sono piccoli: possono confondere i numeri. Controllali prima di decidere.';

  @override
  String get aiLocalConsentModelTitle => 'Il modello';

  @override
  String get aiLocalConsentModelBody =>
      'Lo scarichi da Hugging Face, che vede il tuo indirizzo IP. Ogni modello ha la sua licenza, mostrata prima del download.';

  @override
  String get aiSetupStepLocalModel => 'Modello sul telefono';

  @override
  String get aiSetupStepLocalModelHint =>
      'Scarica un modello e accetta l\'informativa sul dispositivo';

  @override
  String get aiLocalBackendGpu => 'GPU';

  @override
  String get aiLocalBackendCpu => 'CPU';

  @override
  String get aiLocalBackendNpu => 'NPU';

  @override
  String get aiLocalBackendLabel => 'Dove calcola';

  @override
  String get aiLocalBackendGpuHint => 'Più veloce. Consigliata.';

  @override
  String get aiLocalBackendCpuHint =>
      'Più lenta e usa più memoria; con LiteRT-LM il contesto arriva al massimo a 8k.';

  @override
  String aiLocalContextShort(String size) {
    return 'contesto $size';
  }

  @override
  String aiLocalOutputShort(int count) {
    return 'risposta fino a $count token';
  }

  @override
  String aiLocalContextLabel(String count) {
    return 'Contesto: $count token';
  }

  @override
  String get aiLocalContextHint =>
      'Quanto testo il modello tiene presente: dati, report e domande.';

  @override
  String get aiLocalContextMemoryWarning =>
      'Più contesto usa più memoria. Se l\'app si chiude durante un\'analisi, riducilo.';

  @override
  String aiLocalOutputLabel(String count) {
    return 'Risposta massima: $count token';
  }

  @override
  String get aiLocalOutputHint =>
      'Un report tipico ne usa 600–1.000. Più spazio alla risposta lascia meno spazio ai dati.';

  @override
  String aiLocalTemperatureLabel(String value) {
    return 'Temperatura: $value';
  }

  @override
  String get aiLocalTemperatureHint =>
      'Bassa: risposte più fedeli ai numeri. Alta: più varie.';

  @override
  String get aiLocalSpeedTitle => 'Velocità';

  @override
  String aiLocalSpeedValue(String prefill, String decode) {
    return 'Lettura $prefill token/s · scrittura $decode token/s';
  }

  @override
  String get aiLocalSpeedMeasured => 'Misurata su questo telefono';

  @override
  String get aiLocalSpeedCatalog =>
      'Indicativa, misurata su un Galaxy S26 Ultra';

  @override
  String get aiLocalSpeedFallback => 'Non ancora misurata: stima prudente';

  @override
  String get aiLocalMeasure => 'Misura velocità';

  @override
  String get aiLocalMeasuring => 'Misura in corso…';

  @override
  String get aiLocalResetDefaults => 'Ripristina i valori predefiniti';

  @override
  String get aiLocalDeviceTitle => 'Questo telefono';

  @override
  String aiLocalDeviceRam(String size) {
    return 'RAM $size';
  }

  @override
  String aiLocalDeviceFree(String size) {
    return '$size liberi';
  }

  @override
  String get aiLocalDeviceUnknown => 'Memoria e spazio non disponibili';

  @override
  String get aiLocalWifiOnly => 'Scarica solo con Wi-Fi';

  @override
  String get aiLocalWifiOnlyHint =>
      'I modelli pesano qualche GB: senza Wi-Fi il download aspetta e riprende da solo.';

  @override
  String get aiLocalPickingFile => 'Preparazione del file…';

  @override
  String get aiLocalImporting => 'Importazione e verifica del modello…';

  @override
  String get aiLocalInstalledTitle => 'Installati';

  @override
  String get aiLocalInUse => 'in uso';

  @override
  String get aiLocalUnverified => 'non verificato';

  @override
  String get aiLocalUseModel => 'Usa questo modello';

  @override
  String get aiLocalEngineLitert => 'LiteRT-LM';

  @override
  String get aiLocalEngineLitertHint =>
      'Sulla GPU, veloce. Modelli preparati da Google.';

  @override
  String get aiLocalEngineLlama => 'llama.cpp';

  @override
  String get aiLocalEngineLlamaHint =>
      'Qualsiasi file GGUF e quantizzazione, sulla CPU: più lento.';

  @override
  String get aiLocalRecommended => 'Consigliato';

  @override
  String get aiLocalRamFits => 'RAM sufficiente';

  @override
  String get aiLocalRamTight => 'RAM al limite';

  @override
  String get aiLocalRamInsufficient => 'RAM insufficiente';

  @override
  String get aiLocalRamUnknown => 'RAM non nota';

  @override
  String get aiLocalRamWarningTitle => 'Memoria insufficiente';

  @override
  String get aiLocalRamWarningMessage =>
      'Questo telefono ha meno RAM di quella che serve al modello: potrebbe non partire o far chiudere l\'app.';

  @override
  String get aiLocalDownloadAnyway => 'Scarica comunque';

  @override
  String get aiLocalDownload => 'Scarica';

  @override
  String aiLocalProgress(String done, String total) {
    return '$done di $total';
  }

  @override
  String get aiLocalQueued => 'In coda';

  @override
  String aiLocalPaused(String progress) {
    return 'In pausa · $progress';
  }

  @override
  String get aiLocalWaitingForWifi => 'In attesa del Wi-Fi';

  @override
  String get aiLocalVerifying => 'Verifica del file…';

  @override
  String get aiLocalPause => 'Pausa';

  @override
  String get aiLocalResume => 'Riprendi';

  @override
  String get aiLocalRetry => 'Riprova';

  @override
  String get aiLocalCancel => 'Annulla';

  @override
  String aiLocalLicenseBody(String size, String license) {
    return 'Il file pesa $size e viene scaricato da Hugging Face. Il modello è distribuito con licenza $license: scaricandolo la accetti.';
  }

  @override
  String get aiLocalGatedBody =>
      'Questo modello è riservato: accetta la licenza sulla sua pagina Hugging Face e inserisci un token di lettura.';

  @override
  String get aiLocalAcceptAndDownload => 'Accetta e scarica';

  @override
  String get aiLocalDeleteTitle => 'Eliminare il modello?';

  @override
  String aiLocalDeleteMessage(String name) {
    return '$name verrà rimosso dal telefono. Le analisi già fatte restano nella cronologia.';
  }

  @override
  String aiLocalDeleted(String size) {
    return 'Modello eliminato: liberati $size';
  }

  @override
  String get aiLocalImportFile => 'Importa un file';

  @override
  String get aiLocalImportUrl => 'Scarica da URL';

  @override
  String get aiLocalImportAction => 'Importa';

  @override
  String get aiLocalUrlLabel => 'Indirizzo https del file';

  @override
  String get aiLocalNameLabel => 'Nome del modello';

  @override
  String get aiLocalQuantLabel => 'Quantizzazione (es. Q4_K_M)';

  @override
  String get aiLocalShaLabel => 'SHA-256 (facoltativo)';

  @override
  String get aiLocalShaHelper =>
      'Se lo inserisci, il file viene verificato; altrimenti il modello resta \"non verificato\".';

  @override
  String get aiLocalShaInvalid => 'Deve avere 64 caratteri esadecimali.';

  @override
  String aiLocalImported(String name) {
    return '$name importato';
  }

  @override
  String aiLocalImportedUnverified(String name) {
    return '$name importato, non verificato';
  }

  @override
  String get aiLocalTokenAction => 'Token Hugging Face';

  @override
  String get aiLocalTokenLabel => 'Token di lettura';

  @override
  String get aiLocalTokenHelper =>
      'Serve solo per i modelli riservati. Resta sul telefono e viene inviato solo a huggingface.co.';

  @override
  String get aiLocalTokenStored => 'Un token è salvato su questo telefono.';

  @override
  String get aiLocalTokenNone => 'Nessun token salvato.';

  @override
  String get aiLocalTokenSaved => 'Token salvato';

  @override
  String get aiLocalTokenRemoved => 'Token rimosso';

  @override
  String get aiCompactProfile => 'Profilo compatto';

  @override
  String get aiCompactProfileHint =>
      'Meno dettagli e regole più brevi: un prompt più corto.';

  @override
  String get aiCompactProfileHintLocal =>
      'Consigliato sul telefono: meno dettagli, regole più brevi e un prompt che entra nel contesto del modello.';

  @override
  String aiPreviewOnDevice(String model) {
    return 'Elaborato sul telefono con $model';
  }

  @override
  String get aiPreviewNoCost => 'Nessun costo';

  @override
  String aiPreviewCompacted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dettagli sono stati ridotti per stare nel limite.',
      one: 'Un dettaglio è stato ridotto per stare nel limite.',
    );
    return '$_temp0';
  }

  @override
  String get aiRunOnDeviceAction => 'Avvia sul telefono';

  @override
  String aiLocalContextUse(String used, String total) {
    return 'Contesto: $used di $total token';
  }

  @override
  String aiLocalContextParts(String input, String output) {
    return 'dati $input · risposta $output';
  }

  @override
  String get aiLocalCountExact => 'conteggio esatto';

  @override
  String get aiLocalCountEstimated => 'stima';

  @override
  String get aiLocalContextTight =>
      'Quasi pieno: le domande successive avranno poco spazio.';

  @override
  String get aiLocalContextOverflow =>
      'Non entra nel contesto del modello. Prova una di queste soluzioni:';

  @override
  String get aiLocalFixCompact => 'Profilo compatto';

  @override
  String get aiLocalFixFewerTransactions => 'Meno movimenti';

  @override
  String get aiLocalFixShorterAnswer => 'Risposta più corta';

  @override
  String get aiLocalFixLargerContext => 'Contesto più grande';

  @override
  String aiLocalTimeEstimate(String low, String high) {
    return 'Tempo stimato: $low–$high';
  }

  @override
  String get aiLocalTimeRough =>
      'Stima approssimativa: misura la velocità in Impostazioni di esecuzione.';

  @override
  String get aiLocalWarnWarm => 'Il telefono è caldo: sarà più lento.';

  @override
  String get aiLocalWarnBattery =>
      'Batteria sotto il 15%: collega il caricatore.';

  @override
  String get aiLocalWarnMemory =>
      'Poca memoria libera: chiudi le altre app se l\'analisi si interrompe.';

  @override
  String get aiLocalKeepOpen =>
      'Il telefono sta scrivendo. Puoi uscire dall\'app: ti avvisiamo quando ha finito.';

  @override
  String aiLocalTokensPerSecond(String value) {
    return '$value token/s';
  }

  @override
  String get errorCodeAiLocalDownloadNetwork =>
      'Download interrotto dalla rete: riprendi quando la connessione torna.';

  @override
  String get errorCodeAiLocalDownloadGated =>
      'Modello riservato: accetta la licenza su Hugging Face e inserisci un token valido.';

  @override
  String get errorCodeAiLocalDownloadNotFound => 'File non trovato sul server.';

  @override
  String get errorCodeAiLocalDownloadHttp =>
      'Il server ha rifiutato il download.';

  @override
  String get errorCodeAiLocalDownloadNoSpace =>
      'Spazio insufficiente sul telefono per questo modello.';

  @override
  String get errorCodeAiLocalDownloadChecksum =>
      'Il file scaricato non corrisponde a quello atteso ed è stato scartato.';

  @override
  String get errorCodeAiLocalDownloadInsecureUrl =>
      'L\'indirizzo deve iniziare con https://.';

  @override
  String get errorCodeAiLocalImportUnknownFormat =>
      'Formato non riconosciuto: servono file .gguf o .litertlm.';

  @override
  String get aiFeaturesSwitchTitle => 'Funzioni AI';

  @override
  String get aiFeaturesSwitchSubtitle =>
      'Assistente AI, analisi nei Report e in Cronologia, scopo dei portafogli. Spegnendole non si cancella nulla: analisi, chiavi e modelli restano dove sono.';

  @override
  String get aiRunModelLabel => 'Modello';

  @override
  String get aiPendingTitle => 'Risposte non inviate';

  @override
  String get aiPendingIntro =>
      'Report e risposte scritti su questo telefono che il server non ha ancora: la rete mancava quando sono finiti, oppure il server li ha rifiutati. Restano qui finché chi li ha scritti non li invia o li elimina. Chiunque usi l\'app su questo telefono può leggerli.';

  @override
  String get aiPendingEmpty =>
      'Nessuna risposta in attesa: il server ha tutto.';

  @override
  String get aiPendingReport => 'Report';

  @override
  String get aiPendingAnswer => 'Risposta a una domanda';

  @override
  String get aiPendingUnknownOwner => 'account sconosciuto';

  @override
  String get aiPendingWaiting =>
      'In attesa di invio: parte da sola quando l\'autore accede o riapre l\'app.';

  @override
  String aiPendingRefused(String reason) {
    return 'Rifiutato dal server: $reason';
  }

  @override
  String get aiPendingResend => 'Invia ora';

  @override
  String get aiPendingSent => 'Inviato: ora è nella cronologia.';

  @override
  String get aiPendingRefusedAgain =>
      'Il server lo rifiuta ancora: puoi leggerlo qui o eliminarlo.';

  @override
  String get aiPendingNotOwner => 'Solo chi lo ha scritto può inviarlo.';

  @override
  String aiPendingOwnerOnly(String owner) {
    return 'Solo $owner può inviarlo o eliminarlo.';
  }

  @override
  String get aiPendingDeleteTitle => 'Eliminare questa risposta?';

  @override
  String get aiPendingDeleteMessage =>
      'Il testo esiste solo su questo telefono: eliminandolo va perso.';

  @override
  String aiPendingBanner(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count risposte scritte sul telefono non sono ancora sul server',
      one: 'Una risposta scritta sul telefono non è ancora sul server',
    );
    return '$_temp0';
  }

  @override
  String get aiLocalFollowUpUnsupported =>
      'Questa analisi è stata scritta sul telefono: continua le domande da un telefono Android con un modello installato.';

  @override
  String get aiLocalFollowUpNoModel =>
      'Per rispondere serve un modello sul telefono: installane uno da Modelli sul dispositivo.';

  @override
  String aiLocalFollowUpOtherModel(String report, String current) {
    return 'Il modello del report ($report) non è più installato: risponderà $current.';
  }

  @override
  String get bgWorkTitle => 'Analisi AI sul dispositivo';

  @override
  String get bgWorkChannel => 'Attività in corso';

  @override
  String get bgWorkStop => 'Interrompi';

  @override
  String bgDownloading(String name, int percent) {
    return 'Download $name · $percent%';
  }

  @override
  String bgVerifying(String name) {
    return 'Verifica di $name';
  }

  @override
  String bgWaitingWifi(String name) {
    return '$name · in attesa del Wi-Fi';
  }

  @override
  String bgQueued(String name) {
    return '$name · in coda';
  }

  @override
  String get aiNotifyChannel => 'Analisi AI';

  @override
  String get notifyModelReadyTitle => 'Modello pronto';

  @override
  String notifyModelReadyBody(String name) {
    return '$name è installato: puoi usarlo per le analisi.';
  }

  @override
  String get notifyDownloadFailedTitle => 'Download non riuscito';

  @override
  String get aiLeaveTitle => 'L\'analisi è ancora in corso';

  @override
  String get aiLeaveBody =>
      'Il telefono sta ancora scrivendo. Puoi interromperla (il testo scritto finora viene salvato), restare qui o lasciarla continuare in background: ti avvisiamo con una notifica quando ha finito.';

  @override
  String get aiLeaveStop => 'Interrompi';

  @override
  String get aiLeaveStay => 'Resta';

  @override
  String get aiLeaveBackground => 'Continua in background';

  @override
  String bgWritingReport(int words) {
    return 'Scrittura del report · $words parole';
  }

  @override
  String bgWritingAnswer(int words) {
    return 'Scrittura della risposta · $words parole';
  }

  @override
  String get notifyReportReadyTitle => 'Analisi pronta';

  @override
  String get notifyAnswerReadyTitle => 'Risposta pronta';

  @override
  String get notifyAnalysisFailedTitle => 'Analisi interrotta';

  @override
  String get notifyAnalysisFallbackBody => 'Tocca per leggerla.';

  @override
  String get aiChatTitle => 'Chiedi all\'assistente';

  @override
  String get aiChatMenuSubtitle =>
      'Domande libere sui tuoi movimenti, come in una chat';

  @override
  String get aiChatIntro =>
      'Fai una domanda sui tuoi movimenti: quando hai pagato qualcosa, quanto spendi per una voce, quali spese hai ogni anno.';

  @override
  String get aiChatExamplesTitle => 'Per esempio';

  @override
  String get aiChatExampleInsurance =>
      'Quando ho pagato l\'assicurazione della macchina?';

  @override
  String get aiChatExampleFuel => 'Quanto spendo in media al mese di benzina?';

  @override
  String get aiChatExampleYearly => 'Quali spese pago una volta all\'anno?';

  @override
  String get aiChatHint => 'Scrivi la tua domanda';

  @override
  String get aiChatDataNoteCloud =>
      'Per rispondere invia al fornitore tutta la cronologia, con l\'elenco dei movimenti e i loro titoli.';

  @override
  String get aiChatDataNoteOnDevice =>
      'Il modello sul telefono legge tutta la cronologia con l\'elenco dei movimenti; se non entra tutta, a ogni domanda si aggiungono i movimenti più vecchi che le corrispondono.';

  @override
  String get aiChatAttachmentChip => 'Movimenti cercati';

  @override
  String get aiChatAttachmentTitle => 'Movimenti aggiunti alla domanda';

  @override
  String get aiHistoryFilterAll => 'Tutte';

  @override
  String get aiHistoryFilterReports => 'Report';

  @override
  String get aiHistoryFilterChats => 'Chat';

  @override
  String aiChatToolSearch(String query) {
    return 'Cerco tra i movimenti: $query';
  }

  @override
  String get aiChatToolSearchAll => 'Cerco tra i movimenti';

  @override
  String aiChatToolSum(String query) {
    return 'Calcolo i totali: $query';
  }

  @override
  String get aiChatToolSumAll => 'Calcolo i totali';

  @override
  String aiChatSearchesTitle(int count) {
    return 'Ricerche fatte: $count';
  }

  @override
  String aiChatSearchRows(int count) {
    return 'Righe: $count';
  }
}
