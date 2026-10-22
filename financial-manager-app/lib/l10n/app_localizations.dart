import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_it.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('it'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In it, this message translates to:
  /// **'FinancialManager'**
  String get appTitle;

  /// No description provided for @commonRetry.
  ///
  /// In it, this message translates to:
  /// **'Riprova'**
  String get commonRetry;

  /// No description provided for @commonCancel.
  ///
  /// In it, this message translates to:
  /// **'Annulla'**
  String get commonCancel;

  /// No description provided for @commonConfirm.
  ///
  /// In it, this message translates to:
  /// **'Conferma'**
  String get commonConfirm;

  /// No description provided for @errorGenericTitle.
  ///
  /// In it, this message translates to:
  /// **'Qualcosa non ha funzionato'**
  String get errorGenericTitle;

  /// No description provided for @errorNetworkTitle.
  ///
  /// In it, this message translates to:
  /// **'Connessione assente'**
  String get errorNetworkTitle;

  /// No description provided for @errorSessionExpiredTitle.
  ///
  /// In it, this message translates to:
  /// **'Sessione scaduta'**
  String get errorSessionExpiredTitle;

  /// No description provided for @emptyStateDefaultMessage.
  ///
  /// In it, this message translates to:
  /// **'Nessun elemento da mostrare.'**
  String get emptyStateDefaultMessage;

  /// No description provided for @errorCodeNetworkError.
  ///
  /// In it, this message translates to:
  /// **'Connessione assente. Controlla la rete e riprova.'**
  String get errorCodeNetworkError;

  /// No description provided for @errorCodeSessionExpired.
  ///
  /// In it, this message translates to:
  /// **'Sessione scaduta. Accedi di nuovo.'**
  String get errorCodeSessionExpired;

  /// No description provided for @errorCodeRateLimitedGeneric.
  ///
  /// In it, this message translates to:
  /// **'Troppi tentativi. Riprova più tardi.'**
  String get errorCodeRateLimitedGeneric;

  /// No description provided for @errorCodeRateLimitedWithSeconds.
  ///
  /// In it, this message translates to:
  /// **'Troppi tentativi. Riprova tra {seconds} secondi.'**
  String errorCodeRateLimitedWithSeconds(int seconds);

  /// No description provided for @errorCodeUnknownError.
  ///
  /// In it, this message translates to:
  /// **'Si è verificato un errore imprevisto. Riprova.'**
  String get errorCodeUnknownError;

  /// No description provided for @errorCodeWalletNotFound.
  ///
  /// In it, this message translates to:
  /// **'Portafoglio non trovato.'**
  String get errorCodeWalletNotFound;

  /// No description provided for @errorCodeAiDisabled.
  ///
  /// In it, this message translates to:
  /// **'L\'Analisi AI non è attiva su questo server.'**
  String get errorCodeAiDisabled;

  /// No description provided for @errorCodeAiNotConfigured.
  ///
  /// In it, this message translates to:
  /// **'Configura prima fornitore, chiave API e modello.'**
  String get errorCodeAiNotConfigured;

  /// No description provided for @errorCodeAiConsentRequired.
  ///
  /// In it, this message translates to:
  /// **'Per continuare accetta l\'informativa sull\'Analisi AI.'**
  String get errorCodeAiConsentRequired;

  /// No description provided for @errorCodeAiDataChanged.
  ///
  /// In it, this message translates to:
  /// **'I tuoi dati sono cambiati dopo l\'anteprima: controllala di nuovo.'**
  String get errorCodeAiDataChanged;

  /// No description provided for @errorCodeAiStreamInProgress.
  ///
  /// In it, this message translates to:
  /// **'C\'è già un\'analisi in corso: attendi che finisca o interrompila.'**
  String get errorCodeAiStreamInProgress;

  /// No description provided for @errorCodeAiPromptTooLarge.
  ///
  /// In it, this message translates to:
  /// **'Troppi dati per una sola analisi: scegli un periodo più breve, meno portafogli o meno movimenti.'**
  String get errorCodeAiPromptTooLarge;

  /// No description provided for @errorCodeAiFollowupLimit.
  ///
  /// In it, this message translates to:
  /// **'Hai raggiunto il numero massimo di domande per questa analisi: avviane una nuova.'**
  String get errorCodeAiFollowupLimit;

  /// No description provided for @errorCodeAiAnalysisExists.
  ///
  /// In it, this message translates to:
  /// **'Questa analisi è già stata avviata: la trovi nella cronologia.'**
  String get errorCodeAiAnalysisExists;

  /// No description provided for @errorCodeAiAnalysisNotReady.
  ///
  /// In it, this message translates to:
  /// **'Le domande di approfondimento richiedono un report completato.'**
  String get errorCodeAiAnalysisNotReady;

  /// No description provided for @errorCodeAiKeyUnreadable.
  ///
  /// In it, this message translates to:
  /// **'La chiave API salvata non è più leggibile: inseriscila di nuovo.'**
  String get errorCodeAiKeyUnreadable;

  /// No description provided for @errorCodeAiStreamInterrupted.
  ///
  /// In it, this message translates to:
  /// **'L\'analisi si è interrotta prima di terminare.'**
  String get errorCodeAiStreamInterrupted;

  /// No description provided for @errorCodeAiAnswerTooLong.
  ///
  /// In it, this message translates to:
  /// **'La risposta era troppo lunga ed è stata troncata.'**
  String get errorCodeAiAnswerTooLong;

  /// No description provided for @errorCodeAiProviderError.
  ///
  /// In it, this message translates to:
  /// **'Il fornitore AI ha restituito un errore.'**
  String get errorCodeAiProviderError;

  /// No description provided for @errorCodeAiProviderInvalidKey.
  ///
  /// In it, this message translates to:
  /// **'La chiave API non è valida o non ha i permessi necessari.'**
  String get errorCodeAiProviderInvalidKey;

  /// No description provided for @errorCodeAiProviderRateLimited.
  ///
  /// In it, this message translates to:
  /// **'Il fornitore AI sta limitando le richieste: riprova tra poco.'**
  String get errorCodeAiProviderRateLimited;

  /// No description provided for @errorCodeAiProviderQuotaExceeded.
  ///
  /// In it, this message translates to:
  /// **'Credito o quota del fornitore AI esauriti: controlla il tuo account presso il fornitore.'**
  String get errorCodeAiProviderQuotaExceeded;

  /// No description provided for @errorCodeAiProviderContextTooLong.
  ///
  /// In it, this message translates to:
  /// **'Il modello non riesce a leggere così tanti dati: riduci il periodo o i movimenti inclusi.'**
  String get errorCodeAiProviderContextTooLong;

  /// No description provided for @errorCodeAiProviderModelNotFound.
  ///
  /// In it, this message translates to:
  /// **'Il modello scelto non esiste o non è disponibile per la tua chiave.'**
  String get errorCodeAiProviderModelNotFound;

  /// No description provided for @errorCodeAiProviderContentBlocked.
  ///
  /// In it, this message translates to:
  /// **'Il fornitore AI ha bloccato la risposta per i suoi filtri di sicurezza.'**
  String get errorCodeAiProviderContentBlocked;

  /// No description provided for @errorCodeAiProviderUnavailable.
  ///
  /// In it, this message translates to:
  /// **'Il fornitore AI è momentaneamente sovraccarico o non disponibile.'**
  String get errorCodeAiProviderUnavailable;

  /// No description provided for @errorCodeAiProviderTimeout.
  ///
  /// In it, this message translates to:
  /// **'Il fornitore AI ha impiegato troppo tempo e l\'analisi è stata interrotta.'**
  String get errorCodeAiProviderTimeout;

  /// No description provided for @errorCodeAiProviderUnreachable.
  ///
  /// In it, this message translates to:
  /// **'Impossibile raggiungere il fornitore AI.'**
  String get errorCodeAiProviderUnreachable;

  /// No description provided for @errorCodeAiProviderInvalid.
  ///
  /// In it, this message translates to:
  /// **'Fornitore non supportato.'**
  String get errorCodeAiProviderInvalid;

  /// No description provided for @errorCodeAiBaseUrlInvalid.
  ///
  /// In it, this message translates to:
  /// **'Inserisci un indirizzo https valido, senza credenziali né parametri.'**
  String get errorCodeAiBaseUrlInvalid;

  /// No description provided for @errorCodeAiBaseUrlNotAllowed.
  ///
  /// In it, this message translates to:
  /// **'Questo server non può collegarsi a indirizzi privati o locali.'**
  String get errorCodeAiBaseUrlNotAllowed;

  /// No description provided for @errorCodeAiTextTooLong.
  ///
  /// In it, this message translates to:
  /// **'Il testo è troppo lungo.'**
  String get errorCodeAiTextTooLong;

  /// No description provided for @errorCodeValueOutOfRange.
  ///
  /// In it, this message translates to:
  /// **'Valore fuori dai limiti consentiti.'**
  String get errorCodeValueOutOfRange;

  /// No description provided for @errorCodeInvalidValue.
  ///
  /// In it, this message translates to:
  /// **'Valore non valido.'**
  String get errorCodeInvalidValue;

  /// No description provided for @errorCodeAiConsentVersionInvalid.
  ///
  /// In it, this message translates to:
  /// **'L\'informativa è stata aggiornata: rileggila e accettala di nuovo.'**
  String get errorCodeAiConsentVersionInvalid;

  /// No description provided for @errorCodeValidationError.
  ///
  /// In it, this message translates to:
  /// **'Controlla i campi evidenziati.'**
  String get errorCodeValidationError;

  /// No description provided for @errorCodeBadRequest.
  ///
  /// In it, this message translates to:
  /// **'Richiesta malformata.'**
  String get errorCodeBadRequest;

  /// No description provided for @errorCodeUnauthorized.
  ///
  /// In it, this message translates to:
  /// **'Autenticazione richiesta o non valida.'**
  String get errorCodeUnauthorized;

  /// No description provided for @errorCodeForbidden.
  ///
  /// In it, this message translates to:
  /// **'Operazione non consentita.'**
  String get errorCodeForbidden;

  /// No description provided for @errorCodeNotFound.
  ///
  /// In it, this message translates to:
  /// **'Risorsa non trovata.'**
  String get errorCodeNotFound;

  /// No description provided for @errorCodeConflict.
  ///
  /// In it, this message translates to:
  /// **'La risorsa è cambiata rispetto a quanto atteso.'**
  String get errorCodeConflict;

  /// No description provided for @errorCodeInternalError.
  ///
  /// In it, this message translates to:
  /// **'Si è verificato un errore interno.'**
  String get errorCodeInternalError;

  /// No description provided for @errorCodeEmailInUse.
  ///
  /// In it, this message translates to:
  /// **'Email già registrata.'**
  String get errorCodeEmailInUse;

  /// No description provided for @errorCodeUsernameInUse.
  ///
  /// In it, this message translates to:
  /// **'Nome utente già in uso.'**
  String get errorCodeUsernameInUse;

  /// No description provided for @errorCodeInvalidCredentials.
  ///
  /// In it, this message translates to:
  /// **'Credenziali non valide.'**
  String get errorCodeInvalidCredentials;

  /// No description provided for @errorCodeInvalidCurrentPassword.
  ///
  /// In it, this message translates to:
  /// **'La password attuale non è corretta.'**
  String get errorCodeInvalidCurrentPassword;

  /// No description provided for @errorCodeInvalidOrExpiredToken.
  ///
  /// In it, this message translates to:
  /// **'Il link non è valido o è scaduto.'**
  String get errorCodeInvalidOrExpiredToken;

  /// No description provided for @errorCodeInvalidGoogleToken.
  ///
  /// In it, this message translates to:
  /// **'Token Google non valido.'**
  String get errorCodeInvalidGoogleToken;

  /// No description provided for @errorCodeGoogleAccountAlreadyLinked.
  ///
  /// In it, this message translates to:
  /// **'Questo account Google è già collegato a un altro utente.'**
  String get errorCodeGoogleAccountAlreadyLinked;

  /// No description provided for @errorCodeNoAlternativeLoginMethod.
  ///
  /// In it, this message translates to:
  /// **'Imposta prima una password per poter scollegare Google.'**
  String get errorCodeNoAlternativeLoginMethod;

  /// No description provided for @errorCodeIdempotencyKeyReused.
  ///
  /// In it, this message translates to:
  /// **'La richiesta è già stata inviata con dati diversi.'**
  String get errorCodeIdempotencyKeyReused;

  /// No description provided for @errorCodeAccountDeletionPending.
  ///
  /// In it, this message translates to:
  /// **'Questo account è in attesa di eliminazione.'**
  String get errorCodeAccountDeletionPending;

  /// No description provided for @errorCodeAccountLocked.
  ///
  /// In it, this message translates to:
  /// **'Questo account è temporaneamente bloccato. Riprova più tardi.'**
  String get errorCodeAccountLocked;

  /// No description provided for @errorCodeNoPasswordSet.
  ///
  /// In it, this message translates to:
  /// **'Nessuna password impostata per questo account.'**
  String get errorCodeNoPasswordSet;

  /// No description provided for @errorCodeReauthRequired.
  ///
  /// In it, this message translates to:
  /// **'Conferma la password per collegare un account Google.'**
  String get errorCodeReauthRequired;

  /// No description provided for @errorCodeCategoryAlreadyExists.
  ///
  /// In it, this message translates to:
  /// **'Esiste già una categoria con questo nome per questa direzione.'**
  String get errorCodeCategoryAlreadyExists;

  /// No description provided for @errorCodeSystemCategoryNotEditable.
  ///
  /// In it, this message translates to:
  /// **'Le categorie di sistema non possono essere modificate.'**
  String get errorCodeSystemCategoryNotEditable;

  /// No description provided for @errorCodeSystemCategoryNotDeletable.
  ///
  /// In it, this message translates to:
  /// **'Le categorie di sistema non possono essere eliminate.'**
  String get errorCodeSystemCategoryNotDeletable;

  /// No description provided for @errorCodeTemplateAlreadyExists.
  ///
  /// In it, this message translates to:
  /// **'Esiste già un modello con questo titolo per questa direzione.'**
  String get errorCodeTemplateAlreadyExists;

  /// No description provided for @errorCodeExportNotReady.
  ///
  /// In it, this message translates to:
  /// **'L\'esportazione non è ancora pronta.'**
  String get errorCodeExportNotReady;

  /// No description provided for @errorCodeUploadTooLarge.
  ///
  /// In it, this message translates to:
  /// **'Il file supera la dimensione massima consentita.'**
  String get errorCodeUploadTooLarge;

  /// No description provided for @errorCodeImageTooLarge.
  ///
  /// In it, this message translates to:
  /// **'L\'immagine supera le dimensioni massime consentite.'**
  String get errorCodeImageTooLarge;

  /// No description provided for @errorCodeUnsupportedImageFormat.
  ///
  /// In it, this message translates to:
  /// **'Questo formato immagine non è supportato. Usa JPEG, PNG o WebP.'**
  String get errorCodeUnsupportedImageFormat;

  /// No description provided for @errorCodeImageFetchFailed.
  ///
  /// In it, this message translates to:
  /// **'Impossibile scaricare l\'immagine selezionata.'**
  String get errorCodeImageFetchFailed;

  /// No description provided for @errorCodeImageSearchFailed.
  ///
  /// In it, this message translates to:
  /// **'Ricerca immagini non disponibile al momento.'**
  String get errorCodeImageSearchFailed;

  /// No description provided for @errorCodeMediaInUse.
  ///
  /// In it, this message translates to:
  /// **'L\'immagine è ancora in uso e non può essere eliminata.'**
  String get errorCodeMediaInUse;

  /// No description provided for @errorCodeNotEditable.
  ///
  /// In it, this message translates to:
  /// **'Solo le operazioni standard possono essere modificate.'**
  String get errorCodeNotEditable;

  /// No description provided for @errorCodeOpeningBalanceNotDeletable.
  ///
  /// In it, this message translates to:
  /// **'Il saldo iniziale non può essere eliminato direttamente.'**
  String get errorCodeOpeningBalanceNotDeletable;

  /// No description provided for @errorCodeCategoryNotFound.
  ///
  /// In it, this message translates to:
  /// **'Categoria non trovata.'**
  String get errorCodeCategoryNotFound;

  /// No description provided for @errorCodeTemplateNotFound.
  ///
  /// In it, this message translates to:
  /// **'Modello non trovato.'**
  String get errorCodeTemplateNotFound;

  /// No description provided for @errorCodeMediaNotFound.
  ///
  /// In it, this message translates to:
  /// **'Immagine non trovata.'**
  String get errorCodeMediaNotFound;

  /// No description provided for @errorCodeWalletNotMealVoucher.
  ///
  /// In it, this message translates to:
  /// **'Disponibile solo per i portafogli buoni pasto.'**
  String get errorCodeWalletNotMealVoucher;

  /// No description provided for @errorCodeWalletIsMealVoucher.
  ///
  /// In it, this message translates to:
  /// **'Non disponibile per i portafogli buoni pasto: usa le operazioni dedicate ai buoni.'**
  String get errorCodeWalletIsMealVoucher;

  /// No description provided for @errorCodeVoucherInsufficientBalance.
  ///
  /// In it, this message translates to:
  /// **'Non ci sono abbastanza buoni disponibili.'**
  String get errorCodeVoucherInsufficientBalance;

  /// No description provided for @errorCodeVoucherLotAlreadyUsed.
  ///
  /// In it, this message translates to:
  /// **'Alcuni di questi buoni sono già stati spesi o rimossi.'**
  String get errorCodeVoucherLotAlreadyUsed;

  /// No description provided for @errorCodeVoucherLotAlreadyExpired.
  ///
  /// In it, this message translates to:
  /// **'Questo lotto di buoni è già scaduto e non può più essere modificato.'**
  String get errorCodeVoucherLotAlreadyExpired;

  /// No description provided for @errorCodeVoucherAutoAdjustmentNotDeletable.
  ///
  /// In it, this message translates to:
  /// **'Le rettifiche automatiche per buoni scaduti non possono essere eliminate.'**
  String get errorCodeVoucherAutoAdjustmentNotDeletable;

  /// No description provided for @errorCodeOtherWalletRequired.
  ///
  /// In it, this message translates to:
  /// **'Seleziona il portafoglio con cui hai pagato la differenza.'**
  String get errorCodeOtherWalletRequired;

  /// No description provided for @errorCodeOtherWalletNotAllowed.
  ///
  /// In it, this message translates to:
  /// **'I buoni scelti coprono già l\'intera spesa: non serve un altro portafoglio.'**
  String get errorCodeOtherWalletNotAllowed;

  /// No description provided for @errorCodeSameAsVoucherWallet.
  ///
  /// In it, this message translates to:
  /// **'Il portafoglio della differenza deve essere diverso da quello dei buoni.'**
  String get errorCodeSameAsVoucherWallet;

  /// No description provided for @errorCodeInvalidMonth.
  ///
  /// In it, this message translates to:
  /// **'Mese non valido.'**
  String get errorCodeInvalidMonth;

  /// No description provided for @errorCodeInvalidDay.
  ///
  /// In it, this message translates to:
  /// **'Giorno non valido.'**
  String get errorCodeInvalidDay;

  /// No description provided for @errorCodeNotAllowedForWalletType.
  ///
  /// In it, this message translates to:
  /// **'Non consentito per questo tipo di portafoglio.'**
  String get errorCodeNotAllowedForWalletType;

  /// No description provided for @errorCodePurposeLengthInvalid.
  ///
  /// In it, this message translates to:
  /// **'Lo scopo può contenere al massimo 280 caratteri.'**
  String get errorCodePurposeLengthInvalid;

  /// No description provided for @errorCodeLinkTargetNotFound.
  ///
  /// In it, this message translates to:
  /// **'Transazione da collegare non trovata.'**
  String get errorCodeLinkTargetNotFound;

  /// No description provided for @errorCodeLinkTargetNotLinkable.
  ///
  /// In it, this message translates to:
  /// **'Questa transazione non può essere collegata.'**
  String get errorCodeLinkTargetNotLinkable;

  /// No description provided for @errorCodeNotInPaymentGroup.
  ///
  /// In it, this message translates to:
  /// **'Questa transazione non è collegata ad altre.'**
  String get errorCodeNotInPaymentGroup;

  /// No description provided for @errorCodeRequiredField.
  ///
  /// In it, this message translates to:
  /// **'Campo obbligatorio.'**
  String get errorCodeRequiredField;

  /// No description provided for @errorCodeUsernameLengthInvalid.
  ///
  /// In it, this message translates to:
  /// **'Deve avere tra 3 e 40 caratteri.'**
  String get errorCodeUsernameLengthInvalid;

  /// No description provided for @errorCodeInvalidEmail.
  ///
  /// In it, this message translates to:
  /// **'Email non valida.'**
  String get errorCodeInvalidEmail;

  /// No description provided for @errorCodePasswordTooShort.
  ///
  /// In it, this message translates to:
  /// **'Deve avere almeno 8 caratteri.'**
  String get errorCodePasswordTooShort;

  /// No description provided for @errorCodePasswordsDoNotMatch.
  ///
  /// In it, this message translates to:
  /// **'Le password non coincidono.'**
  String get errorCodePasswordsDoNotMatch;

  /// No description provided for @errorCodeInvalidColorFormat.
  ///
  /// In it, this message translates to:
  /// **'Formato colore non valido.'**
  String get errorCodeInvalidColorFormat;

  /// No description provided for @errorCodeNegativeNotAllowed.
  ///
  /// In it, this message translates to:
  /// **'Non può essere negativo.'**
  String get errorCodeNegativeNotAllowed;

  /// No description provided for @errorCodeCurrencyNotSupported.
  ///
  /// In it, this message translates to:
  /// **'Solo EUR è supportato in questa versione.'**
  String get errorCodeCurrencyNotSupported;

  /// No description provided for @errorCodeTermsNotAccepted.
  ///
  /// In it, this message translates to:
  /// **'Devi accettare i termini per procedere.'**
  String get errorCodeTermsNotAccepted;

  /// No description provided for @errorCodeInvalidUuid.
  ///
  /// In it, this message translates to:
  /// **'Deve essere un UUID valido.'**
  String get errorCodeInvalidUuid;

  /// No description provided for @errorCodeInvalidDirection.
  ///
  /// In it, this message translates to:
  /// **'Deve essere CREDIT o DEBIT.'**
  String get errorCodeInvalidDirection;

  /// No description provided for @errorCodeAmountNotPositive.
  ///
  /// In it, this message translates to:
  /// **'Deve essere maggiore di zero.'**
  String get errorCodeAmountNotPositive;

  /// No description provided for @errorCodeAmountImplausible.
  ///
  /// In it, this message translates to:
  /// **'Importo non plausibile.'**
  String get errorCodeAmountImplausible;

  /// No description provided for @errorCodeTitleLengthInvalid.
  ///
  /// In it, this message translates to:
  /// **'Deve avere tra 1 e 120 caratteri.'**
  String get errorCodeTitleLengthInvalid;

  /// No description provided for @errorCodeCurrencyMismatch.
  ///
  /// In it, this message translates to:
  /// **'Deve corrispondere alla valuta del portafoglio.'**
  String get errorCodeCurrencyMismatch;

  /// No description provided for @errorCodeMustBeInteger.
  ///
  /// In it, this message translates to:
  /// **'Deve essere un numero intero.'**
  String get errorCodeMustBeInteger;

  /// No description provided for @errorCodeInvalidRfc3339Date.
  ///
  /// In it, this message translates to:
  /// **'Deve essere una data valida.'**
  String get errorCodeInvalidRfc3339Date;

  /// No description provided for @errorCodeInvalidCategoryScope.
  ///
  /// In it, this message translates to:
  /// **'Deve essere DEBIT, CREDIT o BOTH.'**
  String get errorCodeInvalidCategoryScope;

  /// No description provided for @errorCodeCategoryNameLengthInvalid.
  ///
  /// In it, this message translates to:
  /// **'Deve avere tra 1 e 80 caratteri.'**
  String get errorCodeCategoryNameLengthInvalid;

  /// No description provided for @errorCodeInvalidTheme.
  ///
  /// In it, this message translates to:
  /// **'Deve essere system, light o dark.'**
  String get errorCodeInvalidTheme;

  /// No description provided for @errorCodeInvalidFirstDayOfWeek.
  ///
  /// In it, this message translates to:
  /// **'Deve essere monday o sunday.'**
  String get errorCodeInvalidFirstDayOfWeek;

  /// No description provided for @errorCodeInvalidExportFormat.
  ///
  /// In it, this message translates to:
  /// **'Deve essere csv o json.'**
  String get errorCodeInvalidExportFormat;

  /// No description provided for @errorCodeInvalidTimezone.
  ///
  /// In it, this message translates to:
  /// **'Fuso orario non valido.'**
  String get errorCodeInvalidTimezone;

  /// No description provided for @errorCodeInvalidPreset.
  ///
  /// In it, this message translates to:
  /// **'Valore non valido.'**
  String get errorCodeInvalidPreset;

  /// No description provided for @errorCodeCustomRangeRequired.
  ///
  /// In it, this message translates to:
  /// **'\'from\' e \'to\' sono obbligatori con preset=custom.'**
  String get errorCodeCustomRangeRequired;

  /// No description provided for @errorCodeInvalidGroupBy.
  ///
  /// In it, this message translates to:
  /// **'Deve essere title o category.'**
  String get errorCodeInvalidGroupBy;

  /// No description provided for @errorCodeInvalidMediaKind.
  ///
  /// In it, this message translates to:
  /// **'Deve essere profile, transaction o category.'**
  String get errorCodeInvalidMediaKind;

  /// No description provided for @errorCodeProviderNotSupported.
  ///
  /// In it, this message translates to:
  /// **'Provider non supportato.'**
  String get errorCodeProviderNotSupported;

  /// No description provided for @errorCodeInvalidAmount.
  ///
  /// In it, this message translates to:
  /// **'Importo non valido.'**
  String get errorCodeInvalidAmount;

  /// No description provided for @errorCodeRegistrationSessionExpired.
  ///
  /// In it, this message translates to:
  /// **'Sessione di registrazione scaduta. Riprova con Google.'**
  String get errorCodeRegistrationSessionExpired;

  /// No description provided for @errorCodeExportFailed.
  ///
  /// In it, this message translates to:
  /// **'Esportazione non riuscita. Riprova.'**
  String get errorCodeExportFailed;

  /// No description provided for @commonSave.
  ///
  /// In it, this message translates to:
  /// **'Salva'**
  String get commonSave;

  /// No description provided for @commonContinue.
  ///
  /// In it, this message translates to:
  /// **'Continua'**
  String get commonContinue;

  /// No description provided for @accountScreenTitle.
  ///
  /// In it, this message translates to:
  /// **'Account'**
  String get accountScreenTitle;

  /// No description provided for @accountLogoutConfirmTitle.
  ///
  /// In it, this message translates to:
  /// **'Vuoi uscire?'**
  String get accountLogoutConfirmTitle;

  /// No description provided for @accountLogoutAction.
  ///
  /// In it, this message translates to:
  /// **'Esci'**
  String get accountLogoutAction;

  /// No description provided for @accountLogoutAllConfirmTitle.
  ///
  /// In it, this message translates to:
  /// **'Uscire da tutti i dispositivi?'**
  String get accountLogoutAllConfirmTitle;

  /// No description provided for @accountLogoutAllConfirmMessage.
  ///
  /// In it, this message translates to:
  /// **'Tutte le sessioni attive verranno terminate.'**
  String get accountLogoutAllConfirmMessage;

  /// No description provided for @accountLogoutAllAction.
  ///
  /// In it, this message translates to:
  /// **'Esci ovunque'**
  String get accountLogoutAllAction;

  /// No description provided for @accountLogoutAllMenuTitle.
  ///
  /// In it, this message translates to:
  /// **'Esci da tutti i dispositivi'**
  String get accountLogoutAllMenuTitle;

  /// No description provided for @accountProfileLoadError.
  ///
  /// In it, this message translates to:
  /// **'Impossibile caricare il profilo.'**
  String get accountProfileLoadError;

  /// No description provided for @accountWalletLabel.
  ///
  /// In it, this message translates to:
  /// **'Portafoglio'**
  String get accountWalletLabel;

  /// No description provided for @accountBalanceAdjustmentAction.
  ///
  /// In it, this message translates to:
  /// **'Rettifica saldo'**
  String get accountBalanceAdjustmentAction;

  /// No description provided for @accountWalletsMenuTitle.
  ///
  /// In it, this message translates to:
  /// **'Portafogli'**
  String get accountWalletsMenuTitle;

  /// No description provided for @accountWalletsMenuSubtitle.
  ///
  /// In it, this message translates to:
  /// **'Gestisci i tuoi conti e il contante'**
  String get accountWalletsMenuSubtitle;

  /// No description provided for @walletsScreenTitle.
  ///
  /// In it, this message translates to:
  /// **'Portafogli'**
  String get walletsScreenTitle;

  /// No description provided for @walletsTotalBalanceLabel.
  ///
  /// In it, this message translates to:
  /// **'Saldo totale'**
  String get walletsTotalBalanceLabel;

  /// No description provided for @addWalletAction.
  ///
  /// In it, this message translates to:
  /// **'Nuovo portafoglio'**
  String get addWalletAction;

  /// No description provided for @walletsLoadError.
  ///
  /// In it, this message translates to:
  /// **'Impossibile caricare i portafogli.'**
  String get walletsLoadError;

  /// No description provided for @walletsEmptyStateMessage.
  ///
  /// In it, this message translates to:
  /// **'Nessun portafoglio attivo.'**
  String get walletsEmptyStateMessage;

  /// No description provided for @transferAction.
  ///
  /// In it, this message translates to:
  /// **'Trasferisci'**
  String get transferAction;

  /// No description provided for @newWalletScreenTitle.
  ///
  /// In it, this message translates to:
  /// **'Nuovo portafoglio'**
  String get newWalletScreenTitle;

  /// No description provided for @editWalletScreenTitle.
  ///
  /// In it, this message translates to:
  /// **'Modifica portafoglio'**
  String get editWalletScreenTitle;

  /// No description provided for @walletNameLabel.
  ///
  /// In it, this message translates to:
  /// **'Nome'**
  String get walletNameLabel;

  /// No description provided for @walletPurposeLabel.
  ///
  /// In it, this message translates to:
  /// **'Scopo (facoltativo)'**
  String get walletPurposeLabel;

  /// No description provided for @walletPurposeHint.
  ///
  /// In it, this message translates to:
  /// **'Es. spese quotidiane, fondo emergenze, risparmi per le vacanze'**
  String get walletPurposeHint;

  /// No description provided for @walletPurposeHelper.
  ///
  /// In it, this message translates to:
  /// **'Aiuta l\'Analisi AI a capire a cosa serve questo portafoglio.'**
  String get walletPurposeHelper;

  /// No description provided for @walletTypeLabel.
  ///
  /// In it, this message translates to:
  /// **'Tipo'**
  String get walletTypeLabel;

  /// No description provided for @walletTypeCash.
  ///
  /// In it, this message translates to:
  /// **'Contante'**
  String get walletTypeCash;

  /// No description provided for @walletTypeBank.
  ///
  /// In it, this message translates to:
  /// **'Conto bancario'**
  String get walletTypeBank;

  /// No description provided for @walletTypeOther.
  ///
  /// In it, this message translates to:
  /// **'Altro'**
  String get walletTypeOther;

  /// No description provided for @walletIconLabel.
  ///
  /// In it, this message translates to:
  /// **'Icona'**
  String get walletIconLabel;

  /// No description provided for @walletColorLabel.
  ///
  /// In it, this message translates to:
  /// **'Colore'**
  String get walletColorLabel;

  /// No description provided for @saveWalletAction.
  ///
  /// In it, this message translates to:
  /// **'Salva portafoglio'**
  String get saveWalletAction;

  /// No description provided for @createWalletError.
  ///
  /// In it, this message translates to:
  /// **'Impossibile creare il portafoglio.'**
  String get createWalletError;

  /// No description provided for @updateWalletError.
  ///
  /// In it, this message translates to:
  /// **'Impossibile salvare il portafoglio.'**
  String get updateWalletError;

  /// No description provided for @archiveWalletAction.
  ///
  /// In it, this message translates to:
  /// **'Archivia portafoglio'**
  String get archiveWalletAction;

  /// No description provided for @archiveWalletConfirmTitle.
  ///
  /// In it, this message translates to:
  /// **'Archiviare questo portafoglio?'**
  String get archiveWalletConfirmTitle;

  /// No description provided for @archiveWalletConfirmMessage.
  ///
  /// In it, this message translates to:
  /// **'Il portafoglio verrà archiviato e non sarà più selezionabile per nuove operazioni; la sua cronologia resterà nei report.'**
  String get archiveWalletConfirmMessage;

  /// No description provided for @archiveWalletConfirmMessageWithBalance.
  ///
  /// In it, this message translates to:
  /// **'Il portafoglio ha ancora un saldo di {balance}. Verrà archiviato e non sarà più selezionabile per nuove operazioni; la sua cronologia resterà nei report.'**
  String archiveWalletConfirmMessageWithBalance(String balance);

  /// No description provided for @archiveWalletError.
  ///
  /// In it, this message translates to:
  /// **'Impossibile archiviare il portafoglio.'**
  String get archiveWalletError;

  /// No description provided for @walletDenominationsAction.
  ///
  /// In it, this message translates to:
  /// **'Banconote e monete'**
  String get walletDenominationsAction;

  /// No description provided for @walletDenominationsScreenTitle.
  ///
  /// In it, this message translates to:
  /// **'Banconote e monete'**
  String get walletDenominationsScreenTitle;

  /// No description provided for @denominationCountLabel.
  ///
  /// In it, this message translates to:
  /// **'Quantità'**
  String get denominationCountLabel;

  /// No description provided for @saveDenominationsAction.
  ///
  /// In it, this message translates to:
  /// **'Salva conteggio'**
  String get saveDenominationsAction;

  /// No description provided for @denominationsLoadError.
  ///
  /// In it, this message translates to:
  /// **'Impossibile caricare le banconote e monete.'**
  String get denominationsLoadError;

  /// No description provided for @walletPickerTitle.
  ///
  /// In it, this message translates to:
  /// **'Scegli portafoglio'**
  String get walletPickerTitle;

  /// No description provided for @selectWalletPlaceholder.
  ///
  /// In it, this message translates to:
  /// **'Seleziona un portafoglio'**
  String get selectWalletPlaceholder;

  /// No description provided for @transferSheetTitle.
  ///
  /// In it, this message translates to:
  /// **'Trasferimento tra portafogli'**
  String get transferSheetTitle;

  /// No description provided for @transferSourceWalletLabel.
  ///
  /// In it, this message translates to:
  /// **'Da'**
  String get transferSourceWalletLabel;

  /// No description provided for @transferDestinationWalletLabel.
  ///
  /// In it, this message translates to:
  /// **'A'**
  String get transferDestinationWalletLabel;

  /// No description provided for @transferAmountLabel.
  ///
  /// In it, this message translates to:
  /// **'Importo'**
  String get transferAmountLabel;

  /// No description provided for @transferNoteLabel.
  ///
  /// In it, this message translates to:
  /// **'Nota (opzionale)'**
  String get transferNoteLabel;

  /// No description provided for @submitTransferAction.
  ///
  /// In it, this message translates to:
  /// **'Trasferisci'**
  String get submitTransferAction;

  /// No description provided for @transferSameWalletError.
  ///
  /// In it, this message translates to:
  /// **'Il portafoglio di destinazione deve essere diverso da quello di partenza.'**
  String get transferSameWalletError;

  /// No description provided for @editTransferSheetTitle.
  ///
  /// In it, this message translates to:
  /// **'Modifica trasferimento'**
  String get editTransferSheetTitle;

  /// No description provided for @saveTransferAction.
  ///
  /// In it, this message translates to:
  /// **'Salva trasferimento'**
  String get saveTransferAction;

  /// No description provided for @walletBadgeArchived.
  ///
  /// In it, this message translates to:
  /// **'Archiviato'**
  String get walletBadgeArchived;

  /// No description provided for @allWalletsLabel.
  ///
  /// In it, this message translates to:
  /// **'Tutti i portafogli'**
  String get allWalletsLabel;

  /// No description provided for @walletTypeMealVoucher.
  ///
  /// In it, this message translates to:
  /// **'Buoni pasto'**
  String get walletTypeMealVoucher;

  /// No description provided for @voucherUnitValueLabel.
  ///
  /// In it, this message translates to:
  /// **'Valore del buono'**
  String get voucherUnitValueLabel;

  /// No description provided for @voucherExpiryPolicyLabel.
  ///
  /// In it, this message translates to:
  /// **'Scadenza dei buoni'**
  String get voucherExpiryPolicyLabel;

  /// No description provided for @voucherExpiryCutoffMonthLabel.
  ///
  /// In it, this message translates to:
  /// **'Fino al mese di'**
  String get voucherExpiryCutoffMonthLabel;

  /// No description provided for @voucherExpiryMonthLabel.
  ///
  /// In it, this message translates to:
  /// **'Mese di scadenza'**
  String get voucherExpiryMonthLabel;

  /// No description provided for @voucherExpiryDayLabel.
  ///
  /// In it, this message translates to:
  /// **'Giorno di scadenza'**
  String get voucherExpiryDayLabel;

  /// No description provided for @voucherInitialQuantityLabel.
  ///
  /// In it, this message translates to:
  /// **'Numero di buoni iniziali'**
  String get voucherInitialQuantityLabel;

  /// No description provided for @voucherLoadedAtLabel.
  ///
  /// In it, this message translates to:
  /// **'Data di carico'**
  String get voucherLoadedAtLabel;

  /// No description provided for @voucherLotsAction.
  ///
  /// In it, this message translates to:
  /// **'Buoni pasto'**
  String get voucherLotsAction;

  /// No description provided for @voucherLotsScreenTitle.
  ///
  /// In it, this message translates to:
  /// **'Buoni pasto'**
  String get voucherLotsScreenTitle;

  /// No description provided for @voucherLotsLoadError.
  ///
  /// In it, this message translates to:
  /// **'Impossibile caricare i buoni pasto.'**
  String get voucherLotsLoadError;

  /// No description provided for @voucherActiveSectionTitle.
  ///
  /// In it, this message translates to:
  /// **'Attivi'**
  String get voucherActiveSectionTitle;

  /// No description provided for @voucherActiveEmptyMessage.
  ///
  /// In it, this message translates to:
  /// **'Nessun buono attivo.'**
  String get voucherActiveEmptyMessage;

  /// No description provided for @voucherExpiringSoonSectionTitle.
  ///
  /// In it, this message translates to:
  /// **'In scadenza a breve'**
  String get voucherExpiringSoonSectionTitle;

  /// No description provided for @voucherExpiredSectionTitle.
  ///
  /// In it, this message translates to:
  /// **'Scaduti'**
  String get voucherExpiredSectionTitle;

  /// No description provided for @voucherExpiredEmptyMessage.
  ///
  /// In it, this message translates to:
  /// **'Nessun buono scaduto.'**
  String get voucherExpiredEmptyMessage;

  /// No description provided for @voucherLotQuantityLabel.
  ///
  /// In it, this message translates to:
  /// **'{count} buoni'**
  String voucherLotQuantityLabel(int count);

  /// No description provided for @voucherLotExpiresOnLabel.
  ///
  /// In it, this message translates to:
  /// **'Scade il {date}'**
  String voucherLotExpiresOnLabel(String date);

  /// No description provided for @voucherLotExpiredOnLabel.
  ///
  /// In it, this message translates to:
  /// **'Scaduto il {date}'**
  String voucherLotExpiredOnLabel(String date);

  /// No description provided for @voucherExpiringSoonBadge.
  ///
  /// In it, this message translates to:
  /// **'{count} buoni in scadenza'**
  String voucherExpiringSoonBadge(int count);

  /// No description provided for @addVouchersAction.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi buoni'**
  String get addVouchersAction;

  /// No description provided for @removeVouchersAction.
  ///
  /// In it, this message translates to:
  /// **'Rimuovi buoni'**
  String get removeVouchersAction;

  /// No description provided for @addVouchersSheetTitle.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi buoni'**
  String get addVouchersSheetTitle;

  /// No description provided for @removeVouchersSheetTitle.
  ///
  /// In it, this message translates to:
  /// **'Rimuovi buoni'**
  String get removeVouchersSheetTitle;

  /// No description provided for @voucherQuantityLabel.
  ///
  /// In it, this message translates to:
  /// **'Numero di buoni'**
  String get voucherQuantityLabel;

  /// No description provided for @voucherExpenseAction.
  ///
  /// In it, this message translates to:
  /// **'Spesa con buoni pasto'**
  String get voucherExpenseAction;

  /// No description provided for @voucherExpenseSheetTitle.
  ///
  /// In it, this message translates to:
  /// **'Spesa con buoni pasto'**
  String get voucherExpenseSheetTitle;

  /// No description provided for @editVoucherExpenseSheetTitle.
  ///
  /// In it, this message translates to:
  /// **'Modifica spesa con buoni pasto'**
  String get editVoucherExpenseSheetTitle;

  /// No description provided for @voucherWalletLabel.
  ///
  /// In it, this message translates to:
  /// **'Portafoglio buoni'**
  String get voucherWalletLabel;

  /// No description provided for @voucherOtherWalletLabel.
  ///
  /// In it, this message translates to:
  /// **'Pagato con'**
  String get voucherOtherWalletLabel;

  /// No description provided for @voucherOtherWalletRequiredError.
  ///
  /// In it, this message translates to:
  /// **'Seleziona il portafoglio con cui hai pagato la differenza.'**
  String get voucherOtherWalletRequiredError;

  /// No description provided for @voucherTotalExpenseLabel.
  ///
  /// In it, this message translates to:
  /// **'Totale della spesa'**
  String get voucherTotalExpenseLabel;

  /// No description provided for @voucherShortfallLabel.
  ///
  /// In it, this message translates to:
  /// **'Differenza da pagare: {amount}'**
  String voucherShortfallLabel(String amount);

  /// No description provided for @voucherSuggestedQuantityHelper.
  ///
  /// In it, this message translates to:
  /// **'Minimo consigliato: {count}'**
  String voucherSuggestedQuantityHelper(int count);

  /// No description provided for @submitVoucherExpenseAction.
  ///
  /// In it, this message translates to:
  /// **'Registra spesa'**
  String get submitVoucherExpenseAction;

  /// No description provided for @saveVoucherExpenseAction.
  ///
  /// In it, this message translates to:
  /// **'Salva spesa'**
  String get saveVoucherExpenseAction;

  /// No description provided for @noImageSelectedLabel.
  ///
  /// In it, this message translates to:
  /// **'Nessuna immagine'**
  String get noImageSelectedLabel;

  /// No description provided for @imageSelectedLabel.
  ///
  /// In it, this message translates to:
  /// **'Immagine selezionata'**
  String get imageSelectedLabel;

  /// No description provided for @accountSecurityMenuTitle.
  ///
  /// In it, this message translates to:
  /// **'Sicurezza'**
  String get accountSecurityMenuTitle;

  /// No description provided for @accountSecurityMenuSubtitle.
  ///
  /// In it, this message translates to:
  /// **'Password, sessioni attive, logout'**
  String get accountSecurityMenuSubtitle;

  /// No description provided for @accountLinkedAccountsMenuTitle.
  ///
  /// In it, this message translates to:
  /// **'Account collegati'**
  String get accountLinkedAccountsMenuTitle;

  /// No description provided for @accountPreferencesMenuTitle.
  ///
  /// In it, this message translates to:
  /// **'Preferenze'**
  String get accountPreferencesMenuTitle;

  /// No description provided for @accountPreferencesMenuSubtitle.
  ///
  /// In it, this message translates to:
  /// **'Tema, fuso orario, lingua, saldo, funzioni AI'**
  String get accountPreferencesMenuSubtitle;

  /// No description provided for @accountDataMenuTitle.
  ///
  /// In it, this message translates to:
  /// **'Dati'**
  String get accountDataMenuTitle;

  /// No description provided for @accountDataMenuSubtitle.
  ///
  /// In it, this message translates to:
  /// **'Esporta o elimina il tuo account'**
  String get accountDataMenuSubtitle;

  /// No description provided for @accountPreferencesLoadError.
  ///
  /// In it, this message translates to:
  /// **'Impossibile caricare le preferenze.'**
  String get accountPreferencesLoadError;

  /// No description provided for @themeLabel.
  ///
  /// In it, this message translates to:
  /// **'Tema'**
  String get themeLabel;

  /// No description provided for @themeOptionSystem.
  ///
  /// In it, this message translates to:
  /// **'Sistema'**
  String get themeOptionSystem;

  /// No description provided for @themeOptionLight.
  ///
  /// In it, this message translates to:
  /// **'Chiaro'**
  String get themeOptionLight;

  /// No description provided for @themeOptionDark.
  ///
  /// In it, this message translates to:
  /// **'Scuro'**
  String get themeOptionDark;

  /// No description provided for @firstDayOfWeekLabel.
  ///
  /// In it, this message translates to:
  /// **'Primo giorno della settimana'**
  String get firstDayOfWeekLabel;

  /// No description provided for @weekdayMonday.
  ///
  /// In it, this message translates to:
  /// **'Lunedì'**
  String get weekdayMonday;

  /// No description provided for @weekdaySunday.
  ///
  /// In it, this message translates to:
  /// **'Domenica'**
  String get weekdaySunday;

  /// No description provided for @hideBalanceOnOpenTitle.
  ///
  /// In it, this message translates to:
  /// **'Nascondi saldo all\'apertura'**
  String get hideBalanceOnOpenTitle;

  /// No description provided for @hideBalanceOnOpenSubtitle.
  ///
  /// In it, this message translates to:
  /// **'Il saldo sarà oscurato di default in Home'**
  String get hideBalanceOnOpenSubtitle;

  /// No description provided for @timezoneLabel.
  ///
  /// In it, this message translates to:
  /// **'Fuso orario'**
  String get timezoneLabel;

  /// No description provided for @languageLabel.
  ///
  /// In it, this message translates to:
  /// **'Lingua'**
  String get languageLabel;

  /// No description provided for @deleteAccountConfirmTitle.
  ///
  /// In it, this message translates to:
  /// **'Eliminare l\'account?'**
  String get deleteAccountConfirmTitle;

  /// No description provided for @deleteAccountConfirmMessage.
  ///
  /// In it, this message translates to:
  /// **'Questa azione è irreversibile. Il tuo profilo verrà rimosso; le operazioni registrate restano solo a fini contabili.'**
  String get deleteAccountConfirmMessage;

  /// No description provided for @confirmPasswordDialogTitle.
  ///
  /// In it, this message translates to:
  /// **'Conferma la password'**
  String get confirmPasswordDialogTitle;

  /// No description provided for @currentPasswordOptionalGoogleLabel.
  ///
  /// In it, this message translates to:
  /// **'Password attuale (vuota se solo Google)'**
  String get currentPasswordOptionalGoogleLabel;

  /// No description provided for @deleteAccountAction.
  ///
  /// In it, this message translates to:
  /// **'Elimina account'**
  String get deleteAccountAction;

  /// No description provided for @exportDataSectionTitle.
  ///
  /// In it, this message translates to:
  /// **'Esporta i tuoi dati'**
  String get exportDataSectionTitle;

  /// No description provided for @exportDataDescription.
  ///
  /// In it, this message translates to:
  /// **'CSV per le operazioni, JSON per profilo, portafoglio, categorie, modelli, operazioni e analisi AI.'**
  String get exportDataDescription;

  /// No description provided for @exportCsvAction.
  ///
  /// In it, this message translates to:
  /// **'Esporta CSV'**
  String get exportCsvAction;

  /// No description provided for @exportJsonAction.
  ///
  /// In it, this message translates to:
  /// **'Esporta JSON'**
  String get exportJsonAction;

  /// No description provided for @dangerZoneTitle.
  ///
  /// In it, this message translates to:
  /// **'Zona pericolosa'**
  String get dangerZoneTitle;

  /// No description provided for @accountProfileScreenTitle.
  ///
  /// In it, this message translates to:
  /// **'Profilo'**
  String get accountProfileScreenTitle;

  /// No description provided for @profileUpdatedMessage.
  ///
  /// In it, this message translates to:
  /// **'Profilo aggiornato.'**
  String get profileUpdatedMessage;

  /// No description provided for @verificationEmailSentMessage.
  ///
  /// In it, this message translates to:
  /// **'Email di verifica inviata.'**
  String get verificationEmailSentMessage;

  /// No description provided for @firstNameLabel.
  ///
  /// In it, this message translates to:
  /// **'Nome'**
  String get firstNameLabel;

  /// No description provided for @lastNameLabel.
  ///
  /// In it, this message translates to:
  /// **'Cognome'**
  String get lastNameLabel;

  /// No description provided for @usernameLabel.
  ///
  /// In it, this message translates to:
  /// **'Username'**
  String get usernameLabel;

  /// No description provided for @emailLabel.
  ///
  /// In it, this message translates to:
  /// **'Email'**
  String get emailLabel;

  /// No description provided for @resendVerificationTooltip.
  ///
  /// In it, this message translates to:
  /// **'Invia di nuovo la verifica'**
  String get resendVerificationTooltip;

  /// No description provided for @emailNotVerifiedHint.
  ///
  /// In it, this message translates to:
  /// **'Email non verificata. Tocca l\'icona per reinviare il link.'**
  String get emailNotVerifiedHint;

  /// No description provided for @currentPasswordLabel.
  ///
  /// In it, this message translates to:
  /// **'Password attuale'**
  String get currentPasswordLabel;

  /// No description provided for @googleLinkedSuccessMessage.
  ///
  /// In it, this message translates to:
  /// **'Google collegato con successo.'**
  String get googleLinkedSuccessMessage;

  /// No description provided for @unlinkGoogleConfirmTitle.
  ///
  /// In it, this message translates to:
  /// **'Scollegare Google?'**
  String get unlinkGoogleConfirmTitle;

  /// No description provided for @unlinkGoogleConfirmMessage.
  ///
  /// In it, this message translates to:
  /// **'Potrai comunque accedere con la tua password.'**
  String get unlinkGoogleConfirmMessage;

  /// No description provided for @unlinkGoogleAction.
  ///
  /// In it, this message translates to:
  /// **'Scollega'**
  String get unlinkGoogleAction;

  /// No description provided for @googleUnlinkedSuccessMessage.
  ///
  /// In it, this message translates to:
  /// **'Google scollegato.'**
  String get googleUnlinkedSuccessMessage;

  /// No description provided for @notLinkedLabel.
  ///
  /// In it, this message translates to:
  /// **'Non collegato'**
  String get notLinkedLabel;

  /// No description provided for @linkAction.
  ///
  /// In it, this message translates to:
  /// **'Collega'**
  String get linkAction;

  /// No description provided for @linkedNeverUsedLabel.
  ///
  /// In it, this message translates to:
  /// **'Collegato, mai utilizzato'**
  String get linkedNeverUsedLabel;

  /// No description provided for @lastUsedLabel.
  ///
  /// In it, this message translates to:
  /// **'Ultimo utilizzo: {date}'**
  String lastUsedLabel(String date);

  /// No description provided for @currentBalanceLabel.
  ///
  /// In it, this message translates to:
  /// **'Saldo attuale: {balance}'**
  String currentBalanceLabel(String balance);

  /// No description provided for @reasonOptionalLabel.
  ///
  /// In it, this message translates to:
  /// **'Motivo (opzionale)'**
  String get reasonOptionalLabel;

  /// No description provided for @saveAdjustmentAction.
  ///
  /// In it, this message translates to:
  /// **'Salva rettifica'**
  String get saveAdjustmentAction;

  /// No description provided for @reportTrendTitle.
  ///
  /// In it, this message translates to:
  /// **'Andamento'**
  String get reportTrendTitle;

  /// No description provided for @showChartTooltip.
  ///
  /// In it, this message translates to:
  /// **'Mostra grafico'**
  String get showChartTooltip;

  /// No description provided for @showTableTooltip.
  ///
  /// In it, this message translates to:
  /// **'Mostra tabella (accessibile)'**
  String get showTableTooltip;

  /// No description provided for @noDataForPeriod.
  ///
  /// In it, this message translates to:
  /// **'Nessun dato per il periodo selezionato.'**
  String get noDataForPeriod;

  /// No description provided for @periodColumnLabel.
  ///
  /// In it, this message translates to:
  /// **'Periodo'**
  String get periodColumnLabel;

  /// No description provided for @creditsColumnLabel.
  ///
  /// In it, this message translates to:
  /// **'Entrate'**
  String get creditsColumnLabel;

  /// No description provided for @debitsColumnLabel.
  ///
  /// In it, this message translates to:
  /// **'Uscite'**
  String get debitsColumnLabel;

  /// No description provided for @balanceColumnLabel.
  ///
  /// In it, this message translates to:
  /// **'Saldo'**
  String get balanceColumnLabel;

  /// No description provided for @reportBreakdownTitle.
  ///
  /// In it, this message translates to:
  /// **'Ripartizione'**
  String get reportBreakdownTitle;

  /// No description provided for @groupByTitleOption.
  ///
  /// In it, this message translates to:
  /// **'Per titolo'**
  String get groupByTitleOption;

  /// No description provided for @groupByCategoryOption.
  ///
  /// In it, this message translates to:
  /// **'Per categoria'**
  String get groupByCategoryOption;

  /// No description provided for @noTransactionsForView.
  ///
  /// In it, this message translates to:
  /// **'Nessuna operazione per questa vista.'**
  String get noTransactionsForView;

  /// No description provided for @transactionCountLabel.
  ///
  /// In it, this message translates to:
  /// **'{count} operazioni'**
  String transactionCountLabel(int count);

  /// No description provided for @monthlyComparisonTitle.
  ///
  /// In it, this message translates to:
  /// **'Confronto mensile'**
  String get monthlyComparisonTitle;

  /// No description provided for @monthColumnLabel.
  ///
  /// In it, this message translates to:
  /// **'Mese'**
  String get monthColumnLabel;

  /// No description provided for @netColumnLabel.
  ///
  /// In it, this message translates to:
  /// **'Netto'**
  String get netColumnLabel;

  /// No description provided for @monthDetailSnackbar.
  ///
  /// In it, this message translates to:
  /// **'{month}: entrate {credits}, uscite {debits}, netto {net}'**
  String monthDetailSnackbar(
    String month,
    String credits,
    String debits,
    String net,
  );

  /// No description provided for @filtersTitle.
  ///
  /// In it, this message translates to:
  /// **'Filtri'**
  String get filtersTitle;

  /// No description provided for @typeLabel.
  ///
  /// In it, this message translates to:
  /// **'Tipo'**
  String get typeLabel;

  /// No description provided for @titleFieldLabel.
  ///
  /// In it, this message translates to:
  /// **'Titolo'**
  String get titleFieldLabel;

  /// No description provided for @titleOrDescriptionFilterLabel.
  ///
  /// In it, this message translates to:
  /// **'Titolo o descrizione'**
  String get titleOrDescriptionFilterLabel;

  /// No description provided for @historySearchHint.
  ///
  /// In it, this message translates to:
  /// **'Cerca per titolo o descrizione'**
  String get historySearchHint;

  /// No description provided for @minAmountLabel.
  ///
  /// In it, this message translates to:
  /// **'Importo minimo'**
  String get minAmountLabel;

  /// No description provided for @maxAmountLabel.
  ///
  /// In it, this message translates to:
  /// **'Importo massimo'**
  String get maxAmountLabel;

  /// No description provided for @startDateLabel.
  ///
  /// In it, this message translates to:
  /// **'Data iniziale'**
  String get startDateLabel;

  /// No description provided for @endDateLabel.
  ///
  /// In it, this message translates to:
  /// **'Data finale'**
  String get endDateLabel;

  /// No description provided for @anyLabel.
  ///
  /// In it, this message translates to:
  /// **'Qualsiasi'**
  String get anyLabel;

  /// No description provided for @allCategoriesLabel.
  ///
  /// In it, this message translates to:
  /// **'Tutte le categorie'**
  String get allCategoriesLabel;

  /// No description provided for @resetAction.
  ///
  /// In it, this message translates to:
  /// **'Azzera'**
  String get resetAction;

  /// No description provided for @applyAction.
  ///
  /// In it, this message translates to:
  /// **'Applica'**
  String get applyAction;

  /// No description provided for @typeFilterAll.
  ///
  /// In it, this message translates to:
  /// **'Tutte'**
  String get typeFilterAll;

  /// No description provided for @typeFilterAdjustments.
  ///
  /// In it, this message translates to:
  /// **'Rettifiche'**
  String get typeFilterAdjustments;

  /// No description provided for @typeFilterTransfers.
  ///
  /// In it, this message translates to:
  /// **'Trasferimenti'**
  String get typeFilterTransfers;

  /// No description provided for @categoryPickerTitle.
  ///
  /// In it, this message translates to:
  /// **'Categoria'**
  String get categoryPickerTitle;

  /// No description provided for @categoriesLoadError.
  ///
  /// In it, this message translates to:
  /// **'Impossibile caricare le categorie.'**
  String get categoriesLoadError;

  /// No description provided for @noCategoryLabel.
  ///
  /// In it, this message translates to:
  /// **'Nessuna categoria'**
  String get noCategoryLabel;

  /// No description provided for @createAndSelectAction.
  ///
  /// In it, this message translates to:
  /// **'Crea e seleziona'**
  String get createAndSelectAction;

  /// No description provided for @newCategoryAction.
  ///
  /// In it, this message translates to:
  /// **'Nuova categoria'**
  String get newCategoryAction;

  /// No description provided for @newCategoryNameLabel.
  ///
  /// In it, this message translates to:
  /// **'Nome nuova categoria'**
  String get newCategoryNameLabel;

  /// No description provided for @createCategoryError.
  ///
  /// In it, this message translates to:
  /// **'Impossibile creare la categoria. Riprova.'**
  String get createCategoryError;

  /// No description provided for @categorySearchHint.
  ///
  /// In it, this message translates to:
  /// **'Cerca categoria'**
  String get categorySearchHint;

  /// No description provided for @categorySearchNoResults.
  ///
  /// In it, this message translates to:
  /// **'Nessuna categoria trovata.'**
  String get categorySearchNoResults;

  /// No description provided for @descriptionOptionalLabel.
  ///
  /// In it, this message translates to:
  /// **'Descrizione (facoltativa)'**
  String get descriptionOptionalLabel;

  /// No description provided for @loginAction.
  ///
  /// In it, this message translates to:
  /// **'Accedi'**
  String get loginAction;

  /// No description provided for @forgotPasswordAction.
  ///
  /// In it, this message translates to:
  /// **'Password dimenticata?'**
  String get forgotPasswordAction;

  /// No description provided for @usernameOrEmailLabel.
  ///
  /// In it, this message translates to:
  /// **'Username o email'**
  String get usernameOrEmailLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In it, this message translates to:
  /// **'Password'**
  String get passwordLabel;

  /// No description provided for @orDividerLabel.
  ///
  /// In it, this message translates to:
  /// **'oppure'**
  String get orDividerLabel;

  /// No description provided for @continueWithGoogleAction.
  ///
  /// In it, this message translates to:
  /// **'Continua con Google'**
  String get continueWithGoogleAction;

  /// No description provided for @createAccountAction.
  ///
  /// In it, this message translates to:
  /// **'Crea un account'**
  String get createAccountAction;

  /// No description provided for @confirmRegistrationAction.
  ///
  /// In it, this message translates to:
  /// **'Conferma registrazione'**
  String get confirmRegistrationAction;

  /// No description provided for @nextAction.
  ///
  /// In it, this message translates to:
  /// **'Avanti'**
  String get nextAction;

  /// No description provided for @backAction.
  ///
  /// In it, this message translates to:
  /// **'Indietro'**
  String get backAction;

  /// No description provided for @accountStepTitle.
  ///
  /// In it, this message translates to:
  /// **'Account'**
  String get accountStepTitle;

  /// No description provided for @confirmPasswordLabel.
  ///
  /// In it, this message translates to:
  /// **'Conferma password'**
  String get confirmPasswordLabel;

  /// No description provided for @profileStepTitle.
  ///
  /// In it, this message translates to:
  /// **'Profilo'**
  String get profileStepTitle;

  /// No description provided for @backgroundColorLabel.
  ///
  /// In it, this message translates to:
  /// **'Colore sfondo'**
  String get backgroundColorLabel;

  /// No description provided for @walletStepTitle.
  ///
  /// In it, this message translates to:
  /// **'Portafoglio'**
  String get walletStepTitle;

  /// No description provided for @initialBalanceLabel.
  ///
  /// In it, this message translates to:
  /// **'Saldo iniziale (EUR)'**
  String get initialBalanceLabel;

  /// No description provided for @acceptTermsLabel.
  ///
  /// In it, this message translates to:
  /// **'Accetto i termini di servizio e la privacy policy'**
  String get acceptTermsLabel;

  /// No description provided for @registrationSummaryLabel.
  ///
  /// In it, this message translates to:
  /// **'Riepilogo: {firstName} {lastName}, @{username}, saldo iniziale {balance}'**
  String registrationSummaryLabel(
    Object balance,
    Object firstName,
    Object lastName,
    Object username,
  );

  /// No description provided for @completeRegistrationScreenTitle.
  ///
  /// In it, this message translates to:
  /// **'Completa la registrazione'**
  String get completeRegistrationScreenTitle;

  /// No description provided for @backToLoginAction.
  ///
  /// In it, this message translates to:
  /// **'Torna al login'**
  String get backToLoginAction;

  /// No description provided for @googleSignInConfirmedMessage.
  ///
  /// In it, this message translates to:
  /// **'Accesso confermato con Google come {email}.'**
  String googleSignInConfirmedMessage(String email);

  /// No description provided for @localPasswordOptionalHint.
  ///
  /// In it, this message translates to:
  /// **'Password locale (facoltativa: senza, potrai accedere solo con Google)'**
  String get localPasswordOptionalHint;

  /// No description provided for @completeRegistrationAction.
  ///
  /// In it, this message translates to:
  /// **'Completa registrazione'**
  String get completeRegistrationAction;

  /// No description provided for @forgotPasswordScreenTitle.
  ///
  /// In it, this message translates to:
  /// **'Password dimenticata'**
  String get forgotPasswordScreenTitle;

  /// No description provided for @forgotPasswordSuccessMessage.
  ///
  /// In it, this message translates to:
  /// **'Se l\'indirizzo è registrato, riceverai a breve un\'email con le istruzioni per reimpostare la password.'**
  String get forgotPasswordSuccessMessage;

  /// No description provided for @forgotPasswordInstructionsMessage.
  ///
  /// In it, this message translates to:
  /// **'Inserisci la tua email: ti invieremo le istruzioni per reimpostare la password.'**
  String get forgotPasswordInstructionsMessage;

  /// No description provided for @sendAction.
  ///
  /// In it, this message translates to:
  /// **'Invia'**
  String get sendAction;

  /// No description provided for @transactionDetailScreenTitle.
  ///
  /// In it, this message translates to:
  /// **'Dettaglio operazione'**
  String get transactionDetailScreenTitle;

  /// No description provided for @editTooltip.
  ///
  /// In it, this message translates to:
  /// **'Modifica'**
  String get editTooltip;

  /// No description provided for @deleteTooltip.
  ///
  /// In it, this message translates to:
  /// **'Elimina'**
  String get deleteTooltip;

  /// No description provided for @commonDelete.
  ///
  /// In it, this message translates to:
  /// **'Elimina'**
  String get commonDelete;

  /// No description provided for @deleteTransactionConfirmTitle.
  ///
  /// In it, this message translates to:
  /// **'Eliminare questa operazione?'**
  String get deleteTransactionConfirmTitle;

  /// No description provided for @deleteTransactionConfirmMessage.
  ///
  /// In it, this message translates to:
  /// **'Il saldo verrà aggiornato di conseguenza.'**
  String get deleteTransactionConfirmMessage;

  /// No description provided for @openingBalanceKindLabel.
  ///
  /// In it, this message translates to:
  /// **'Saldo iniziale'**
  String get openingBalanceKindLabel;

  /// No description provided for @balanceAdjustmentKindLabel.
  ///
  /// In it, this message translates to:
  /// **'Rettifica saldo'**
  String get balanceAdjustmentKindLabel;

  /// No description provided for @manualKindLabel.
  ///
  /// In it, this message translates to:
  /// **'Manuale'**
  String get manualKindLabel;

  /// No description provided for @transferKindLabel.
  ///
  /// In it, this message translates to:
  /// **'Trasferimento'**
  String get transferKindLabel;

  /// No description provided for @walletLabel.
  ///
  /// In it, this message translates to:
  /// **'Portafoglio'**
  String get walletLabel;

  /// No description provided for @categoryLabel.
  ///
  /// In it, this message translates to:
  /// **'Categoria'**
  String get categoryLabel;

  /// No description provided for @sourceLabel.
  ///
  /// In it, this message translates to:
  /// **'Origine'**
  String get sourceLabel;

  /// No description provided for @dateAndTimeLabel.
  ///
  /// In it, this message translates to:
  /// **'Data e ora'**
  String get dateAndTimeLabel;

  /// No description provided for @descriptionLabel.
  ///
  /// In it, this message translates to:
  /// **'Descrizione'**
  String get descriptionLabel;

  /// No description provided for @createdLabel.
  ///
  /// In it, this message translates to:
  /// **'Creata il'**
  String get createdLabel;

  /// No description provided for @lastModifiedLabel.
  ///
  /// In it, this message translates to:
  /// **'Ultima modifica'**
  String get lastModifiedLabel;

  /// No description provided for @editOpeningBalanceSheetTitle.
  ///
  /// In it, this message translates to:
  /// **'Modifica saldo iniziale'**
  String get editOpeningBalanceSheetTitle;

  /// No description provided for @editOpeningBalanceHint.
  ///
  /// In it, this message translates to:
  /// **'È il punto di partenza del portafoglio, non una rettifica: modificarlo cambia anche report e grafici passati.'**
  String get editOpeningBalanceHint;

  /// No description provided for @saveOpeningBalanceAction.
  ///
  /// In it, this message translates to:
  /// **'Salva saldo iniziale'**
  String get saveOpeningBalanceAction;

  /// No description provided for @addLinkedPaymentTooltip.
  ///
  /// In it, this message translates to:
  /// **'Aggiungi pagamento collegato'**
  String get addLinkedPaymentTooltip;

  /// No description provided for @linkedPaymentsSectionTitle.
  ///
  /// In it, this message translates to:
  /// **'Pagamenti collegati'**
  String get linkedPaymentsSectionTitle;

  /// No description provided for @linkedPaymentsTotalLabel.
  ///
  /// In it, this message translates to:
  /// **'Totale speso'**
  String get linkedPaymentsTotalLabel;

  /// No description provided for @linkedPaymentsCurrentLabel.
  ///
  /// In it, this message translates to:
  /// **'Stai visualizzando'**
  String get linkedPaymentsCurrentLabel;

  /// No description provided for @linkedPaymentsEmptyStateMessage.
  ///
  /// In it, this message translates to:
  /// **'Nessun pagamento collegato ancora.'**
  String get linkedPaymentsEmptyStateMessage;

  /// No description provided for @linkedPaymentsMemberCountLabel.
  ///
  /// In it, this message translates to:
  /// **'{count} pagamenti'**
  String linkedPaymentsMemberCountLabel(int count);

  /// No description provided for @mediaPickerRecentTab.
  ///
  /// In it, this message translates to:
  /// **'Recenti'**
  String get mediaPickerRecentTab;

  /// No description provided for @mediaPickerLibraryTab.
  ///
  /// In it, this message translates to:
  /// **'Libreria'**
  String get mediaPickerLibraryTab;

  /// No description provided for @mediaPickerSearchTab.
  ///
  /// In it, this message translates to:
  /// **'Cerca'**
  String get mediaPickerSearchTab;

  /// No description provided for @mediaPickerUploadTab.
  ///
  /// In it, this message translates to:
  /// **'Carica'**
  String get mediaPickerUploadTab;

  /// No description provided for @mediaLoadErrorMessage.
  ///
  /// In it, this message translates to:
  /// **'Impossibile caricare le immagini.'**
  String get mediaLoadErrorMessage;

  /// No description provided for @mediaEmptyStateMessage.
  ///
  /// In it, this message translates to:
  /// **'Nessuna immagine disponibile.'**
  String get mediaEmptyStateMessage;

  /// No description provided for @mediaUntitledLabel.
  ///
  /// In it, this message translates to:
  /// **'Senza titolo'**
  String get mediaUntitledLabel;

  /// No description provided for @mediaLibrarySearchHint.
  ///
  /// In it, this message translates to:
  /// **'Cerca nella libreria'**
  String get mediaLibrarySearchHint;

  /// No description provided for @mediaSearchHint.
  ///
  /// In it, this message translates to:
  /// **'Cerca immagini'**
  String get mediaSearchHint;

  /// No description provided for @mediaSearchMinCharsMessage.
  ///
  /// In it, this message translates to:
  /// **'Digita almeno 2 caratteri per cercare.'**
  String get mediaSearchMinCharsMessage;

  /// No description provided for @mediaSearchNoResultsMessage.
  ///
  /// In it, this message translates to:
  /// **'Nessun risultato.'**
  String get mediaSearchNoResultsMessage;

  /// No description provided for @mediaSearchUnavailableMessage.
  ///
  /// In it, this message translates to:
  /// **'Ricerca non disponibile al momento.'**
  String get mediaSearchUnavailableMessage;

  /// No description provided for @mediaSelectFailedMessage.
  ///
  /// In it, this message translates to:
  /// **'Impossibile selezionare questa immagine.'**
  String get mediaSelectFailedMessage;

  /// No description provided for @mediaCropScreenTitle.
  ///
  /// In it, this message translates to:
  /// **'Ritaglia immagine'**
  String get mediaCropScreenTitle;

  /// No description provided for @mediaCameraAction.
  ///
  /// In it, this message translates to:
  /// **'Fotocamera'**
  String get mediaCameraAction;

  /// No description provided for @mediaGalleryAction.
  ///
  /// In it, this message translates to:
  /// **'Galleria'**
  String get mediaGalleryAction;

  /// No description provided for @mediaUploadFailedMessage.
  ///
  /// In it, this message translates to:
  /// **'Caricamento non riuscito. Riprova.'**
  String get mediaUploadFailedMessage;

  /// No description provided for @mediaRenameDialogTitle.
  ///
  /// In it, this message translates to:
  /// **'Rinomina immagine'**
  String get mediaRenameDialogTitle;

  /// No description provided for @mediaNameLabel.
  ///
  /// In it, this message translates to:
  /// **'Nome'**
  String get mediaNameLabel;

  /// No description provided for @mediaRenameFailedMessage.
  ///
  /// In it, this message translates to:
  /// **'Impossibile rinominare l\'immagine.'**
  String get mediaRenameFailedMessage;

  /// No description provided for @aiAssistantMenuTitle.
  ///
  /// In it, this message translates to:
  /// **'Assistente AI'**
  String get aiAssistantMenuTitle;

  /// No description provided for @aiAssistantMenuSubtitle.
  ///
  /// In it, this message translates to:
  /// **'Analizza le tue finanze con un modello AI'**
  String get aiAssistantMenuSubtitle;

  /// No description provided for @aiAssistantTitle.
  ///
  /// In it, this message translates to:
  /// **'Assistente AI'**
  String get aiAssistantTitle;

  /// No description provided for @aiUnavailableTitle.
  ///
  /// In it, this message translates to:
  /// **'Analisi AI non disponibile'**
  String get aiUnavailableTitle;

  /// No description provided for @aiUnavailableBody.
  ///
  /// In it, this message translates to:
  /// **'Questo server non ha attivato l\'Analisi AI. Chi gestisce il server può abilitarla impostando AI_KEY_ENCRYPTION_KEY.'**
  String get aiUnavailableBody;

  /// No description provided for @aiSetupTitle.
  ///
  /// In it, this message translates to:
  /// **'Prepara la tua prima analisi'**
  String get aiSetupTitle;

  /// No description provided for @aiSetupDoneTitle.
  ///
  /// In it, this message translates to:
  /// **'Tutto pronto'**
  String get aiSetupDoneTitle;

  /// No description provided for @aiSetupProgress.
  ///
  /// In it, this message translates to:
  /// **'{done} di {total} passaggi completati'**
  String aiSetupProgress(int done, int total);

  /// No description provided for @aiSetupOptional.
  ///
  /// In it, this message translates to:
  /// **'facoltativo'**
  String get aiSetupOptional;

  /// No description provided for @aiSetupStepProvider.
  ///
  /// In it, this message translates to:
  /// **'Fornitore, chiave e modello'**
  String get aiSetupStepProvider;

  /// No description provided for @aiSetupStepProviderHint.
  ///
  /// In it, this message translates to:
  /// **'Scegli il servizio AI e inserisci la tua chiave API'**
  String get aiSetupStepProviderHint;

  /// No description provided for @aiSetupStepContext.
  ///
  /// In it, this message translates to:
  /// **'Contesto personale'**
  String get aiSetupStepContext;

  /// No description provided for @aiSetupStepContextHint.
  ///
  /// In it, this message translates to:
  /// **'Obiettivi e situazione, per consigli su misura'**
  String get aiSetupStepContextHint;

  /// No description provided for @aiSetupStepPurposes.
  ///
  /// In it, this message translates to:
  /// **'Scopo dei portafogli'**
  String get aiSetupStepPurposes;

  /// No description provided for @aiSetupStepPurposesHint.
  ///
  /// In it, this message translates to:
  /// **'A cosa serve ciascun portafoglio'**
  String get aiSetupStepPurposesHint;

  /// No description provided for @aiSetupStepFirstAnalysis.
  ///
  /// In it, this message translates to:
  /// **'Prima analisi'**
  String get aiSetupStepFirstAnalysis;

  /// No description provided for @aiSetupStepFirstAnalysisHint.
  ///
  /// In it, this message translates to:
  /// **'Dalla sezione Report, scheda Analisi AI'**
  String get aiSetupStepFirstAnalysisHint;

  /// No description provided for @aiProviderMenuTitle.
  ///
  /// In it, this message translates to:
  /// **'Fornitore e chiave API'**
  String get aiProviderMenuTitle;

  /// No description provided for @aiProviderMenuNotConfigured.
  ///
  /// In it, this message translates to:
  /// **'Non configurato'**
  String get aiProviderMenuNotConfigured;

  /// No description provided for @aiContextMenuTitle.
  ///
  /// In it, this message translates to:
  /// **'Contesto personale'**
  String get aiContextMenuTitle;

  /// No description provided for @aiContextMenuFilled.
  ///
  /// In it, this message translates to:
  /// **'Compilato'**
  String get aiContextMenuFilled;

  /// No description provided for @aiContextMenuEmpty.
  ///
  /// In it, this message translates to:
  /// **'Non ancora compilato'**
  String get aiContextMenuEmpty;

  /// No description provided for @aiWalletPurposesMenuTitle.
  ///
  /// In it, this message translates to:
  /// **'Scopo dei portafogli'**
  String get aiWalletPurposesMenuTitle;

  /// No description provided for @aiWalletPurposesProgress.
  ///
  /// In it, this message translates to:
  /// **'{done} di {total} portafogli con uno scopo'**
  String aiWalletPurposesProgress(int done, int total);

  /// No description provided for @aiConsentMenuTitle.
  ///
  /// In it, this message translates to:
  /// **'Privacy e consenso'**
  String get aiConsentMenuTitle;

  /// No description provided for @aiConsentMenuPending.
  ///
  /// In it, this message translates to:
  /// **'Da accettare prima della prima analisi'**
  String get aiConsentMenuPending;

  /// No description provided for @aiConsentMenuAccepted.
  ///
  /// In it, this message translates to:
  /// **'Accettato'**
  String get aiConsentMenuAccepted;

  /// No description provided for @aiConsentRevokeAction.
  ///
  /// In it, this message translates to:
  /// **'Revoca'**
  String get aiConsentRevokeAction;

  /// No description provided for @aiConsentRevokeConfirmTitle.
  ///
  /// In it, this message translates to:
  /// **'Revocare il consenso?'**
  String get aiConsentRevokeConfirmTitle;

  /// No description provided for @aiConsentRevokeConfirmMessage.
  ///
  /// In it, this message translates to:
  /// **'Non potrai avviare analisi finché non lo accetterai di nuovo. Le analisi salvate restano nella cronologia.'**
  String get aiConsentRevokeConfirmMessage;

  /// No description provided for @aiConsentTitle.
  ///
  /// In it, this message translates to:
  /// **'Prima di iniziare'**
  String get aiConsentTitle;

  /// No description provided for @aiConsentIntro.
  ///
  /// In it, this message translates to:
  /// **'L\'Analisi AI invia un riepilogo dei tuoi dati al fornitore AI che scegli tu, usando la tua chiave API. Prima di ogni invio vedrai esattamente cosa viene inviato.'**
  String get aiConsentIntro;

  /// No description provided for @aiConsentSentTitle.
  ///
  /// In it, this message translates to:
  /// **'Cosa viene inviato'**
  String get aiConsentSentTitle;

  /// No description provided for @aiConsentSentAggregates.
  ///
  /// In it, this message translates to:
  /// **'Totali, andamento mensile, categorie e voci principali del periodo scelto'**
  String get aiConsentSentAggregates;

  /// No description provided for @aiConsentSentWallets.
  ///
  /// In it, this message translates to:
  /// **'Nome, tipo, scopo e saldo dei portafogli inclusi'**
  String get aiConsentSentWallets;

  /// No description provided for @aiConsentSentTransactions.
  ///
  /// In it, this message translates to:
  /// **'Solo se lo attivi: l\'elenco dei movimenti, anche con titoli anonimizzati'**
  String get aiConsentSentTransactions;

  /// No description provided for @aiConsentSentContext.
  ///
  /// In it, this message translates to:
  /// **'Solo se lo attivi: il contesto personale che hai scritto'**
  String get aiConsentSentContext;

  /// No description provided for @aiConsentNeverTitle.
  ///
  /// In it, this message translates to:
  /// **'Cosa non viene mai inviato'**
  String get aiConsentNeverTitle;

  /// No description provided for @aiConsentNeverBody.
  ///
  /// In it, this message translates to:
  /// **'Email, nome, nome utente, identificativi dell\'account e immagini'**
  String get aiConsentNeverBody;

  /// No description provided for @aiConsentKeyTitle.
  ///
  /// In it, this message translates to:
  /// **'La tua chiave API'**
  String get aiConsentKeyTitle;

  /// No description provided for @aiConsentKeyBody.
  ///
  /// In it, this message translates to:
  /// **'Resta cifrata sul server e non viene mai mostrata di nuovo né esportata'**
  String get aiConsentKeyBody;

  /// No description provided for @aiConsentProviderTitle.
  ///
  /// In it, this message translates to:
  /// **'Il fornitore'**
  String get aiConsentProviderTitle;

  /// No description provided for @aiConsentProviderBody.
  ///
  /// In it, this message translates to:
  /// **'Tratta i dati secondo le sue condizioni: verifica per quanto tempo conserva le richieste e se le usa per addestrare i modelli'**
  String get aiConsentProviderBody;

  /// No description provided for @aiConsentRevokeTitle.
  ///
  /// In it, this message translates to:
  /// **'Puoi cambiare idea'**
  String get aiConsentRevokeTitle;

  /// No description provided for @aiConsentRevokeBody.
  ///
  /// In it, this message translates to:
  /// **'Revoca il consenso e cancella le analisi in qualsiasi momento da Assistente AI'**
  String get aiConsentRevokeBody;

  /// No description provided for @aiConsentAccept.
  ///
  /// In it, this message translates to:
  /// **'Ho capito, accetto'**
  String get aiConsentAccept;

  /// No description provided for @aiConsentDecline.
  ///
  /// In it, this message translates to:
  /// **'Non ora'**
  String get aiConsentDecline;

  /// No description provided for @aiProviderLabel.
  ///
  /// In it, this message translates to:
  /// **'Fornitore'**
  String get aiProviderLabel;

  /// No description provided for @aiProviderCompatible.
  ///
  /// In it, this message translates to:
  /// **'Compatibile OpenAI (Mistral, Groq, OpenRouter, Ollama…)'**
  String get aiProviderCompatible;

  /// No description provided for @aiProviderHintAnthropic.
  ///
  /// In it, this message translates to:
  /// **'Crea una chiave su console.anthropic.com → API keys.'**
  String get aiProviderHintAnthropic;

  /// No description provided for @aiProviderHintOpenai.
  ///
  /// In it, this message translates to:
  /// **'Crea una chiave su platform.openai.com → API keys.'**
  String get aiProviderHintOpenai;

  /// No description provided for @aiProviderHintGemini.
  ///
  /// In it, this message translates to:
  /// **'Crea una chiave su aistudio.google.com → Get API key.'**
  String get aiProviderHintGemini;

  /// No description provided for @aiProviderHintCompatible.
  ///
  /// In it, this message translates to:
  /// **'Per qualsiasi servizio che espone l\'API di OpenAI: inserisci il suo indirizzo, di solito terminante in /v1.'**
  String get aiProviderHintCompatible;

  /// No description provided for @aiBaseUrlLabel.
  ///
  /// In it, this message translates to:
  /// **'Indirizzo del servizio (base URL)'**
  String get aiBaseUrlLabel;

  /// No description provided for @aiBaseUrlHelper.
  ///
  /// In it, this message translates to:
  /// **'Indirizzi privati o locali (es. Ollama in casa) funzionano solo se chi gestisce il server lo ha permesso.'**
  String get aiBaseUrlHelper;

  /// No description provided for @aiApiKeyLabel.
  ///
  /// In it, this message translates to:
  /// **'Chiave API'**
  String get aiApiKeyLabel;

  /// No description provided for @aiApiKeyOptionalLabel.
  ///
  /// In it, this message translates to:
  /// **'Chiave API (se richiesta)'**
  String get aiApiKeyOptionalLabel;

  /// No description provided for @aiApiKeyHelper.
  ///
  /// In it, this message translates to:
  /// **'Viene cifrata sul server: dopo il salvataggio vedrai solo le ultime cifre.'**
  String get aiApiKeyHelper;

  /// No description provided for @aiApiKeyWillBeRemoved.
  ///
  /// In it, this message translates to:
  /// **'La chiave salvata verrà rimossa al salvataggio.'**
  String get aiApiKeyWillBeRemoved;

  /// No description provided for @aiApiKeyStored.
  ///
  /// In it, this message translates to:
  /// **'Chiave salvata {hint}'**
  String aiApiKeyStored(String hint);

  /// No description provided for @aiApiKeyReplace.
  ///
  /// In it, this message translates to:
  /// **'Sostituisci'**
  String get aiApiKeyReplace;

  /// No description provided for @aiApiKeyRemove.
  ///
  /// In it, this message translates to:
  /// **'Rimuovi'**
  String get aiApiKeyRemove;

  /// No description provided for @aiApiKeyShow.
  ///
  /// In it, this message translates to:
  /// **'Mostra chiave'**
  String get aiApiKeyShow;

  /// No description provided for @aiApiKeyHide.
  ///
  /// In it, this message translates to:
  /// **'Nascondi chiave'**
  String get aiApiKeyHide;

  /// No description provided for @aiModelLabel.
  ///
  /// In it, this message translates to:
  /// **'Modello'**
  String get aiModelLabel;

  /// No description provided for @aiModelHelper.
  ///
  /// In it, this message translates to:
  /// **'Premi «Carica modelli» per sceglierlo dall\'elenco del fornitore, oppure scrivine il nome.'**
  String get aiModelHelper;

  /// No description provided for @aiModelsLoaded.
  ///
  /// In it, this message translates to:
  /// **'{count} modelli disponibili'**
  String aiModelsLoaded(int count);

  /// No description provided for @aiModelsNoneFound.
  ///
  /// In it, this message translates to:
  /// **'Il fornitore non ha restituito modelli: scrivi il nome a mano.'**
  String get aiModelsNoneFound;

  /// No description provided for @aiLoadModels.
  ///
  /// In it, this message translates to:
  /// **'Carica modelli'**
  String get aiLoadModels;

  /// No description provided for @aiTestConnection.
  ///
  /// In it, this message translates to:
  /// **'Verifica connessione'**
  String get aiTestConnection;

  /// No description provided for @aiTestOk.
  ///
  /// In it, this message translates to:
  /// **'Funziona: {model} ha risposto in {ms} ms.'**
  String aiTestOk(String model, int ms);

  /// No description provided for @aiTestOkKeyOnly.
  ///
  /// In it, this message translates to:
  /// **'Chiave valida (risposta in {ms} ms). Scegli un modello per verificarlo.'**
  String aiTestOkKeyOnly(int ms);

  /// No description provided for @aiLastTestOk.
  ///
  /// In it, this message translates to:
  /// **'Ultima verifica riuscita.'**
  String get aiLastTestOk;

  /// No description provided for @aiLastTestFailed.
  ///
  /// In it, this message translates to:
  /// **'Ultima verifica non riuscita.'**
  String get aiLastTestFailed;

  /// No description provided for @aiAdvancedSettings.
  ///
  /// In it, this message translates to:
  /// **'Impostazioni avanzate'**
  String get aiAdvancedSettings;

  /// No description provided for @aiMaxOutputTokensLabel.
  ///
  /// In it, this message translates to:
  /// **'Lunghezza massima della risposta (token)'**
  String get aiMaxOutputTokensLabel;

  /// No description provided for @aiMaxOutputTokensHelper.
  ///
  /// In it, this message translates to:
  /// **'Tra {min} e {max}. Più è alto, più il report può essere lungo e costare.'**
  String aiMaxOutputTokensHelper(int min, int max);

  /// No description provided for @aiPricesTitle.
  ///
  /// In it, this message translates to:
  /// **'Prezzi (facoltativi)'**
  String get aiPricesTitle;

  /// No description provided for @aiPricesHelper.
  ///
  /// In it, this message translates to:
  /// **'Prezzo per milione di token del tuo modello, nella valuta del fornitore: serve solo per stimare il costo.'**
  String get aiPricesHelper;

  /// No description provided for @aiInputPriceLabel.
  ///
  /// In it, this message translates to:
  /// **'Input'**
  String get aiInputPriceLabel;

  /// No description provided for @aiOutputPriceLabel.
  ///
  /// In it, this message translates to:
  /// **'Output'**
  String get aiOutputPriceLabel;

  /// No description provided for @aiDefaultIncludeTransactions.
  ///
  /// In it, this message translates to:
  /// **'Includi i singoli movimenti di default'**
  String get aiDefaultIncludeTransactions;

  /// No description provided for @aiDefaultIncludeTransactionsHint.
  ///
  /// In it, this message translates to:
  /// **'Analisi più precise, ma più dati inviati e più token.'**
  String get aiDefaultIncludeTransactionsHint;

  /// No description provided for @aiDefaultAnonymizeTitles.
  ///
  /// In it, this message translates to:
  /// **'Anonimizza i titoli di default'**
  String get aiDefaultAnonymizeTitles;

  /// No description provided for @aiDefaultAnonymizeTitlesHint.
  ///
  /// In it, this message translates to:
  /// **'I nomi dei movimenti diventano «Voce 1», «Voce 2»…'**
  String get aiDefaultAnonymizeTitlesHint;

  /// No description provided for @aiSaveSettings.
  ///
  /// In it, this message translates to:
  /// **'Salva'**
  String get aiSaveSettings;

  /// No description provided for @aiForgetProviderTitle.
  ///
  /// In it, this message translates to:
  /// **'Dimenticare questo fornitore?'**
  String get aiForgetProviderTitle;

  /// No description provided for @aiForgetProviderMessage.
  ///
  /// In it, this message translates to:
  /// **'La chiave API salvata viene eliminata dal server.'**
  String get aiForgetProviderMessage;

  /// No description provided for @aiForgetProviderAction.
  ///
  /// In it, this message translates to:
  /// **'Elimina chiave e fornitore'**
  String get aiForgetProviderAction;

  /// No description provided for @aiContextIntro.
  ///
  /// In it, this message translates to:
  /// **'Queste informazioni aiutano l\'AI a darti consigli adatti alla tua situazione. Sono tutte facoltative e le invii solo se includi il contesto personale in un\'analisi.'**
  String get aiContextIntro;

  /// No description provided for @aiNotSpecified.
  ///
  /// In it, this message translates to:
  /// **'Non specificato'**
  String get aiNotSpecified;

  /// No description provided for @aiHouseholdLabel.
  ///
  /// In it, this message translates to:
  /// **'Persone nel nucleo familiare'**
  String get aiHouseholdLabel;

  /// No description provided for @aiHouseholdValue.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{1 persona} other{{count} persone}}'**
  String aiHouseholdValue(int count);

  /// No description provided for @aiHouseholdLess.
  ///
  /// In it, this message translates to:
  /// **'Una persona in meno'**
  String get aiHouseholdLess;

  /// No description provided for @aiHouseholdMore.
  ///
  /// In it, this message translates to:
  /// **'Una persona in più'**
  String get aiHouseholdMore;

  /// No description provided for @aiIncomeTypeLabel.
  ///
  /// In it, this message translates to:
  /// **'Tipo di reddito'**
  String get aiIncomeTypeLabel;

  /// No description provided for @aiIncomeEmployee.
  ///
  /// In it, this message translates to:
  /// **'Lavoro dipendente'**
  String get aiIncomeEmployee;

  /// No description provided for @aiIncomeSelfEmployed.
  ///
  /// In it, this message translates to:
  /// **'Lavoro autonomo'**
  String get aiIncomeSelfEmployed;

  /// No description provided for @aiIncomeStudent.
  ///
  /// In it, this message translates to:
  /// **'Studente'**
  String get aiIncomeStudent;

  /// No description provided for @aiIncomeRetired.
  ///
  /// In it, this message translates to:
  /// **'Pensione'**
  String get aiIncomeRetired;

  /// No description provided for @aiIncomeUnemployed.
  ///
  /// In it, this message translates to:
  /// **'Senza reddito da lavoro'**
  String get aiIncomeUnemployed;

  /// No description provided for @aiIncomeMixed.
  ///
  /// In it, this message translates to:
  /// **'Misto'**
  String get aiIncomeMixed;

  /// No description provided for @aiIncomeOther.
  ///
  /// In it, this message translates to:
  /// **'Altro'**
  String get aiIncomeOther;

  /// No description provided for @aiAboutMeLabel.
  ///
  /// In it, this message translates to:
  /// **'Su di me'**
  String get aiAboutMeLabel;

  /// No description provided for @aiAboutMeHint.
  ///
  /// In it, this message translates to:
  /// **'Es. vivo in affitto a Milano, ho un\'auto, lo stipendio arriva il 27'**
  String get aiAboutMeHint;

  /// No description provided for @aiGoalsLabel.
  ///
  /// In it, this message translates to:
  /// **'Obiettivi'**
  String get aiGoalsLabel;

  /// No description provided for @aiGoalsHint.
  ///
  /// In it, this message translates to:
  /// **'Es. mettere da parte 5.000 € entro giugno, ridurre le spese per mangiare fuori'**
  String get aiGoalsHint;

  /// No description provided for @aiIgnoreLabel.
  ///
  /// In it, this message translates to:
  /// **'Cose da ignorare o da interpretare'**
  String get aiIgnoreLabel;

  /// No description provided for @aiIgnoreHint.
  ///
  /// In it, this message translates to:
  /// **'Es. il bonifico a Marco è un prestito che mi restituisce; a luglio ho pagato l\'assicurazione annuale'**
  String get aiIgnoreHint;

  /// No description provided for @aiResponseStyleLabel.
  ///
  /// In it, this message translates to:
  /// **'Stile delle risposte'**
  String get aiResponseStyleLabel;

  /// No description provided for @aiStyleDefault.
  ///
  /// In it, this message translates to:
  /// **'Standard'**
  String get aiStyleDefault;

  /// No description provided for @aiStyleConcise.
  ///
  /// In it, this message translates to:
  /// **'Conciso'**
  String get aiStyleConcise;

  /// No description provided for @aiStyleDetailed.
  ///
  /// In it, this message translates to:
  /// **'Dettagliato'**
  String get aiStyleDetailed;

  /// No description provided for @aiContextPrivacyNote.
  ///
  /// In it, this message translates to:
  /// **'Non scrivere qui dati come IBAN, codice fiscale o password: non servono all\'analisi.'**
  String get aiContextPrivacyNote;

  /// No description provided for @aiSaveContext.
  ///
  /// In it, this message translates to:
  /// **'Salva'**
  String get aiSaveContext;

  /// No description provided for @aiWalletPurposesIntro.
  ///
  /// In it, this message translates to:
  /// **'Indica a cosa serve ogni portafoglio: l\'AI potrà dirti se lo stai usando come previsto e suggerirti come organizzarti meglio.'**
  String get aiWalletPurposesIntro;

  /// No description provided for @aiWalletPurposesEmpty.
  ///
  /// In it, this message translates to:
  /// **'Non hai ancora portafogli attivi.'**
  String get aiWalletPurposesEmpty;

  /// No description provided for @aiWalletNoPurpose.
  ///
  /// In it, this message translates to:
  /// **'Nessuno scopo'**
  String get aiWalletNoPurpose;

  /// No description provided for @aiPurposeSuggestionDaily.
  ///
  /// In it, this message translates to:
  /// **'Spese quotidiane'**
  String get aiPurposeSuggestionDaily;

  /// No description provided for @aiPurposeSuggestionSavings.
  ///
  /// In it, this message translates to:
  /// **'Risparmi'**
  String get aiPurposeSuggestionSavings;

  /// No description provided for @aiPurposeSuggestionEmergency.
  ///
  /// In it, this message translates to:
  /// **'Fondo emergenze'**
  String get aiPurposeSuggestionEmergency;

  /// No description provided for @aiPurposeSuggestionHome.
  ///
  /// In it, this message translates to:
  /// **'Spese di casa e bollette'**
  String get aiPurposeSuggestionHome;

  /// No description provided for @aiPurposeSuggestionLeisure.
  ///
  /// In it, this message translates to:
  /// **'Tempo libero e viaggi'**
  String get aiPurposeSuggestionLeisure;

  /// No description provided for @aiSavePurpose.
  ///
  /// In it, this message translates to:
  /// **'Salva scopo'**
  String get aiSavePurpose;

  /// No description provided for @aiNewAnalysisTitle.
  ///
  /// In it, this message translates to:
  /// **'Nuova analisi AI'**
  String get aiNewAnalysisTitle;

  /// No description provided for @aiHistoryTitle.
  ///
  /// In it, this message translates to:
  /// **'Cronologia analisi'**
  String get aiHistoryTitle;

  /// No description provided for @aiHistoryMenuSubtitle.
  ///
  /// In it, this message translates to:
  /// **'Rileggi, rinomina o elimina le analisi'**
  String get aiHistoryMenuSubtitle;

  /// No description provided for @aiNotReadyTitle.
  ///
  /// In it, this message translates to:
  /// **'Configura prima l\'Analisi AI'**
  String get aiNotReadyTitle;

  /// No description provided for @aiNotReadyBody.
  ///
  /// In it, this message translates to:
  /// **'Scegli un fornitore, inserisci la chiave API e un modello.'**
  String get aiNotReadyBody;

  /// No description provided for @aiGoToSetup.
  ///
  /// In it, this message translates to:
  /// **'Configura'**
  String get aiGoToSetup;

  /// No description provided for @aiWhatToAnalyze.
  ///
  /// In it, this message translates to:
  /// **'Cosa vuoi analizzare'**
  String get aiWhatToAnalyze;

  /// No description provided for @aiCustomQuestionLabel.
  ///
  /// In it, this message translates to:
  /// **'La tua domanda'**
  String get aiCustomQuestionLabel;

  /// No description provided for @aiCustomQuestionHint.
  ///
  /// In it, this message translates to:
  /// **'Es. quanto ho speso per mangiare fuori e come è cambiato nei mesi?'**
  String get aiCustomQuestionHint;

  /// No description provided for @aiPeriodLabel.
  ///
  /// In it, this message translates to:
  /// **'Periodo'**
  String get aiPeriodLabel;

  /// No description provided for @aiPeriodLast30Days.
  ///
  /// In it, this message translates to:
  /// **'Ultimi 30 giorni'**
  String get aiPeriodLast30Days;

  /// No description provided for @aiPeriodLast12Months.
  ///
  /// In it, this message translates to:
  /// **'Ultimi 12 mesi'**
  String get aiPeriodLast12Months;

  /// No description provided for @aiPeriodCurrentMonth.
  ///
  /// In it, this message translates to:
  /// **'Mese corrente'**
  String get aiPeriodCurrentMonth;

  /// No description provided for @aiPeriodCurrentYear.
  ///
  /// In it, this message translates to:
  /// **'Anno corrente'**
  String get aiPeriodCurrentYear;

  /// No description provided for @aiPeriodAllTime.
  ///
  /// In it, this message translates to:
  /// **'Tutta la cronologia'**
  String get aiPeriodAllTime;

  /// No description provided for @aiPeriodCustom.
  ///
  /// In it, this message translates to:
  /// **'Personalizzato'**
  String get aiPeriodCustom;

  /// No description provided for @aiPeriodUntil.
  ///
  /// In it, this message translates to:
  /// **'Fino al {date}'**
  String aiPeriodUntil(String date);

  /// No description provided for @aiWalletsLabel.
  ///
  /// In it, this message translates to:
  /// **'Portafogli'**
  String get aiWalletsLabel;

  /// No description provided for @aiAllWallets.
  ///
  /// In it, this message translates to:
  /// **'Tutti'**
  String get aiAllWallets;

  /// No description provided for @aiDataToSend.
  ///
  /// In it, this message translates to:
  /// **'Dati da inviare'**
  String get aiDataToSend;

  /// No description provided for @aiDataToSendHint.
  ///
  /// In it, this message translates to:
  /// **'Periodo, portafogli e totali vengono sempre inviati. Più dati scegli, più l\'analisi è ricca e più token consuma.'**
  String get aiDataToSendHint;

  /// No description provided for @aiSectionMonthly.
  ///
  /// In it, this message translates to:
  /// **'Andamento mensile'**
  String get aiSectionMonthly;

  /// No description provided for @aiSectionCategories.
  ///
  /// In it, this message translates to:
  /// **'Categorie'**
  String get aiSectionCategories;

  /// No description provided for @aiSectionTitles.
  ///
  /// In it, this message translates to:
  /// **'Voci principali'**
  String get aiSectionTitles;

  /// No description provided for @aiSectionTransfers.
  ///
  /// In it, this message translates to:
  /// **'Trasferimenti'**
  String get aiSectionTransfers;

  /// No description provided for @aiSectionRecurring.
  ///
  /// In it, this message translates to:
  /// **'Spese ricorrenti'**
  String get aiSectionRecurring;

  /// No description provided for @aiSectionPersonalContext.
  ///
  /// In it, this message translates to:
  /// **'Contesto personale'**
  String get aiSectionPersonalContext;

  /// No description provided for @aiIncludeTransactions.
  ///
  /// In it, this message translates to:
  /// **'Includi i singoli movimenti'**
  String get aiIncludeTransactions;

  /// No description provided for @aiIncludeTransactionsHint.
  ///
  /// In it, this message translates to:
  /// **'Utile per le anomalie; invia data, importo, titolo e categoria dei movimenti più recenti.'**
  String get aiIncludeTransactionsHint;

  /// No description provided for @aiMaxTransactionsValue.
  ///
  /// In it, this message translates to:
  /// **'max {count}'**
  String aiMaxTransactionsValue(int count);

  /// No description provided for @aiIncludeAdjustments.
  ///
  /// In it, this message translates to:
  /// **'Includi le rettifiche di saldo'**
  String get aiIncludeAdjustments;

  /// No description provided for @aiIncludeAdjustmentsHint.
  ///
  /// In it, this message translates to:
  /// **'Di solito correggono errori di registrazione: meglio lasciarle fuori.'**
  String get aiIncludeAdjustmentsHint;

  /// No description provided for @aiPreviewAction.
  ///
  /// In it, this message translates to:
  /// **'Anteprima'**
  String get aiPreviewAction;

  /// No description provided for @aiPreviewTitle.
  ///
  /// In it, this message translates to:
  /// **'Anteprima'**
  String get aiPreviewTitle;

  /// No description provided for @aiPreviewMissing.
  ///
  /// In it, this message translates to:
  /// **'Nessuna anteprima: torna indietro e preparane una.'**
  String get aiPreviewMissing;

  /// No description provided for @aiPreviewSentTo.
  ///
  /// In it, this message translates to:
  /// **'Sarà inviato a {provider} · {model}'**
  String aiPreviewSentTo(String provider, String model);

  /// No description provided for @aiPreviewWallets.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{1 portafoglio} other{{count} portafogli}}'**
  String aiPreviewWallets(int count);

  /// No description provided for @aiPreviewOnlyTotals.
  ///
  /// In it, this message translates to:
  /// **'Solo periodo, portafogli e totali'**
  String get aiPreviewOnlyTotals;

  /// No description provided for @aiPreviewSections.
  ///
  /// In it, this message translates to:
  /// **'Sezioni: {sections}'**
  String aiPreviewSections(String sections);

  /// No description provided for @aiPreviewNoTransactions.
  ///
  /// In it, this message translates to:
  /// **'Nessun movimento singolo'**
  String get aiPreviewNoTransactions;

  /// No description provided for @aiPreviewTransactions.
  ///
  /// In it, this message translates to:
  /// **'{count} movimenti singoli ({omitted} meno recenti esclusi)'**
  String aiPreviewTransactions(int count, int omitted);

  /// No description provided for @aiPreviewAnonymized.
  ///
  /// In it, this message translates to:
  /// **'Titoli dei movimenti anonimizzati'**
  String get aiPreviewAnonymized;

  /// No description provided for @aiPreviewWithContext.
  ///
  /// In it, this message translates to:
  /// **'Contesto personale incluso'**
  String get aiPreviewWithContext;

  /// No description provided for @aiPreviewTokens.
  ///
  /// In it, this message translates to:
  /// **'~{tokens} token in input'**
  String aiPreviewTokens(String tokens);

  /// No description provided for @aiPreviewCost.
  ///
  /// In it, this message translates to:
  /// **'costo max ~{cost}'**
  String aiPreviewCost(String cost);

  /// No description provided for @aiInstructionsLabel.
  ///
  /// In it, this message translates to:
  /// **'Istruzioni'**
  String get aiInstructionsLabel;

  /// No description provided for @aiInstructionsHint.
  ///
  /// In it, this message translates to:
  /// **'Puoi modificarle: è l\'unica parte del testo che decidi tu.'**
  String get aiInstructionsHint;

  /// No description provided for @aiInstructionsRequired.
  ///
  /// In it, this message translates to:
  /// **'Scrivi le istruzioni prima di inviare.'**
  String get aiInstructionsRequired;

  /// No description provided for @aiRestoreInstructions.
  ///
  /// In it, this message translates to:
  /// **'Ripristina'**
  String get aiRestoreInstructions;

  /// No description provided for @aiSystemPromptLabel.
  ///
  /// In it, this message translates to:
  /// **'Regole per il modello'**
  String get aiSystemPromptLabel;

  /// No description provided for @aiSystemPromptHint.
  ///
  /// In it, this message translates to:
  /// **'Fisse: formato del report, uso corretto dei dati, protezioni'**
  String get aiSystemPromptHint;

  /// No description provided for @aiDataBlockLabel.
  ///
  /// In it, this message translates to:
  /// **'Dati inviati'**
  String get aiDataBlockLabel;

  /// No description provided for @aiDataBlockHint.
  ///
  /// In it, this message translates to:
  /// **'Generati dal server dai tuoi movimenti, non modificabili'**
  String get aiDataBlockHint;

  /// No description provided for @aiSendAction.
  ///
  /// In it, this message translates to:
  /// **'Invia e analizza'**
  String get aiSendAction;

  /// No description provided for @aiAnalysisTitle.
  ///
  /// In it, this message translates to:
  /// **'Analisi AI'**
  String get aiAnalysisTitle;

  /// No description provided for @aiDataSentTitle.
  ///
  /// In it, this message translates to:
  /// **'Cosa è stato inviato'**
  String get aiDataSentTitle;

  /// No description provided for @aiDataSentHint.
  ///
  /// In it, this message translates to:
  /// **'Istruzioni e dati esattamente come inviati'**
  String get aiDataSentHint;

  /// No description provided for @aiCopyAction.
  ///
  /// In it, this message translates to:
  /// **'Copia testo'**
  String get aiCopyAction;

  /// No description provided for @aiShareAction.
  ///
  /// In it, this message translates to:
  /// **'Condividi'**
  String get aiShareAction;

  /// No description provided for @aiCopied.
  ///
  /// In it, this message translates to:
  /// **'Testo copiato'**
  String get aiCopied;

  /// No description provided for @aiRefreshPreview.
  ///
  /// In it, this message translates to:
  /// **'Aggiorna anteprima'**
  String get aiRefreshPreview;

  /// No description provided for @aiTokensUsed.
  ///
  /// In it, this message translates to:
  /// **'{input} in / {output} out token'**
  String aiTokensUsed(String input, String output);

  /// No description provided for @aiCostValue.
  ///
  /// In it, this message translates to:
  /// **'costo ~{cost}'**
  String aiCostValue(String cost);

  /// No description provided for @aiThinking.
  ///
  /// In it, this message translates to:
  /// **'Il modello sta scrivendo…'**
  String get aiThinking;

  /// No description provided for @aiAnswerStopped.
  ///
  /// In it, this message translates to:
  /// **'Interrotta: il testo qui sopra è parziale.'**
  String get aiAnswerStopped;

  /// No description provided for @aiAnswerTruncated.
  ///
  /// In it, this message translates to:
  /// **'Risposta troncata al limite di token: puoi alzarlo nelle impostazioni avanzate.'**
  String get aiAnswerTruncated;

  /// No description provided for @aiWaitForAnswer.
  ///
  /// In it, this message translates to:
  /// **'Attendi la fine della risposta…'**
  String get aiWaitForAnswer;

  /// No description provided for @aiFollowUpUnavailable.
  ///
  /// In it, this message translates to:
  /// **'Domande disponibili a report completato'**
  String get aiFollowUpUnavailable;

  /// No description provided for @aiFollowUpLimitReached.
  ///
  /// In it, this message translates to:
  /// **'Limite di domande raggiunto'**
  String get aiFollowUpLimitReached;

  /// No description provided for @aiAskFollowUpHint.
  ///
  /// In it, this message translates to:
  /// **'Fai una domanda ({left} rimaste)'**
  String aiAskFollowUpHint(int left);

  /// No description provided for @aiStopAction.
  ///
  /// In it, this message translates to:
  /// **'Interrompi'**
  String get aiStopAction;

  /// No description provided for @aiAskAction.
  ///
  /// In it, this message translates to:
  /// **'Invia domanda'**
  String get aiAskAction;

  /// No description provided for @aiHistoryEmpty.
  ///
  /// In it, this message translates to:
  /// **'Nessuna analisi ancora. Avviane una dalla sezione Report.'**
  String get aiHistoryEmpty;

  /// No description provided for @aiDeleteAnalysisTitle.
  ///
  /// In it, this message translates to:
  /// **'Eliminare l\'analisi?'**
  String get aiDeleteAnalysisTitle;

  /// No description provided for @aiDeleteAction.
  ///
  /// In it, this message translates to:
  /// **'Elimina'**
  String get aiDeleteAction;

  /// No description provided for @aiDeleteAllAction.
  ///
  /// In it, this message translates to:
  /// **'Elimina tutte'**
  String get aiDeleteAllAction;

  /// No description provided for @aiDeleteAllTitle.
  ///
  /// In it, this message translates to:
  /// **'Eliminare tutte le analisi?'**
  String get aiDeleteAllTitle;

  /// No description provided for @aiDeleteAllMessage.
  ///
  /// In it, this message translates to:
  /// **'Report e conversazioni vengono eliminati definitivamente.'**
  String get aiDeleteAllMessage;

  /// No description provided for @aiRenameAction.
  ///
  /// In it, this message translates to:
  /// **'Rinomina'**
  String get aiRenameAction;

  /// No description provided for @aiRenameTitle.
  ///
  /// In it, this message translates to:
  /// **'Rinomina analisi'**
  String get aiRenameTitle;

  /// No description provided for @aiCancel.
  ///
  /// In it, this message translates to:
  /// **'Annulla'**
  String get aiCancel;

  /// No description provided for @aiReportsCardTitle.
  ///
  /// In it, this message translates to:
  /// **'Analisi AI'**
  String get aiReportsCardTitle;

  /// No description provided for @aiReportsCardBody.
  ///
  /// In it, this message translates to:
  /// **'Fatti spiegare i tuoi numeri: un report personalizzato e domande di approfondimento.'**
  String get aiReportsCardBody;

  /// No description provided for @aiReportsCardSetupBody.
  ///
  /// In it, this message translates to:
  /// **'Collega il tuo fornitore AI preferito per ottenere report personalizzati sulle tue finanze.'**
  String get aiReportsCardSetupBody;

  /// No description provided for @aiReportsCardStart.
  ///
  /// In it, this message translates to:
  /// **'Analizza'**
  String get aiReportsCardStart;

  /// No description provided for @aiHistoryAnalyzeAction.
  ///
  /// In it, this message translates to:
  /// **'Analizza con AI i movimenti filtrati'**
  String get aiHistoryAnalyzeAction;

  /// No description provided for @aiHistoryAnalyzeAdjustments.
  ///
  /// In it, this message translates to:
  /// **'L\'Analisi AI considera entrate e uscite: togli il filtro «rettifiche» per analizzare questi movimenti.'**
  String get aiHistoryAnalyzeAdjustments;

  /// No description provided for @aiHistoryAnalyzeTransfers.
  ///
  /// In it, this message translates to:
  /// **'I trasferimenti spostano denaro tra i tuoi portafogli e non vengono analizzati: togli il filtro «trasferimenti».'**
  String get aiHistoryAnalyzeTransfers;

  /// No description provided for @aiPeriodLastMonth.
  ///
  /// In it, this message translates to:
  /// **'Mese scorso'**
  String get aiPeriodLastMonth;

  /// No description provided for @aiPeriodLastQuarter.
  ///
  /// In it, this message translates to:
  /// **'Trimestre scorso'**
  String get aiPeriodLastQuarter;

  /// No description provided for @aiDateFrom.
  ///
  /// In it, this message translates to:
  /// **'Da'**
  String get aiDateFrom;

  /// No description provided for @aiDateTo.
  ///
  /// In it, this message translates to:
  /// **'A'**
  String get aiDateTo;

  /// No description provided for @aiDateFromEmpty.
  ///
  /// In it, this message translates to:
  /// **'Dall\'inizio'**
  String get aiDateFromEmpty;

  /// No description provided for @aiDateToEmpty.
  ///
  /// In it, this message translates to:
  /// **'Oggi'**
  String get aiDateToEmpty;

  /// No description provided for @aiDateClear.
  ///
  /// In it, this message translates to:
  /// **'Rimuovi data'**
  String get aiDateClear;

  /// No description provided for @aiFiltersTitle.
  ///
  /// In it, this message translates to:
  /// **'Filtri'**
  String get aiFiltersTitle;

  /// No description provided for @aiFiltersFromHistoryTitle.
  ///
  /// In it, this message translates to:
  /// **'Filtri dalla Cronologia'**
  String get aiFiltersFromHistoryTitle;

  /// No description provided for @aiFiltersHint.
  ///
  /// In it, this message translates to:
  /// **'L\'analisi considera solo i movimenti che rispettano questi filtri. Saldi e trasferimenti non vengono inclusi.'**
  String get aiFiltersHint;

  /// No description provided for @aiFilterExpenses.
  ///
  /// In it, this message translates to:
  /// **'Solo uscite'**
  String get aiFilterExpenses;

  /// No description provided for @aiFilterIncome.
  ///
  /// In it, this message translates to:
  /// **'Solo entrate'**
  String get aiFilterIncome;

  /// No description provided for @aiFilterCategory.
  ///
  /// In it, this message translates to:
  /// **'Categoria: {name}'**
  String aiFilterCategory(String name);

  /// No description provided for @aiFilterTitle.
  ///
  /// In it, this message translates to:
  /// **'Contiene «{text}»'**
  String aiFilterTitle(String text);

  /// No description provided for @aiFilterAmountMin.
  ///
  /// In it, this message translates to:
  /// **'Da {amount}'**
  String aiFilterAmountMin(String amount);

  /// No description provided for @aiFilterAmountMax.
  ///
  /// In it, this message translates to:
  /// **'Fino a {amount}'**
  String aiFilterAmountMax(String amount);

  /// No description provided for @aiProviderOnDevice.
  ///
  /// In it, this message translates to:
  /// **'Sul dispositivo'**
  String get aiProviderOnDevice;

  /// No description provided for @errorCodeAiOnDeviceDisabled.
  ///
  /// In it, this message translates to:
  /// **'L\'analisi sul dispositivo non è attiva su questo server.'**
  String get errorCodeAiOnDeviceDisabled;

  /// No description provided for @errorCodeAiLocalConsentRequired.
  ///
  /// In it, this message translates to:
  /// **'Per continuare accetta l\'informativa sull\'analisi sul dispositivo.'**
  String get errorCodeAiLocalConsentRequired;

  /// No description provided for @errorCodeAiAnalysisOnDevice.
  ///
  /// In it, this message translates to:
  /// **'Questa analisi è stata scritta sul telefono: continuala da lì.'**
  String get errorCodeAiAnalysisOnDevice;

  /// No description provided for @errorCodeAiAnalysisNotOnDevice.
  ///
  /// In it, this message translates to:
  /// **'Questa analisi è stata scritta da un fornitore cloud.'**
  String get errorCodeAiAnalysisNotOnDevice;

  /// No description provided for @errorCodeAiMessageFinished.
  ///
  /// In it, this message translates to:
  /// **'Questa risposta era già stata salvata.'**
  String get errorCodeAiMessageFinished;

  /// No description provided for @errorCodeAiLocalEngineError.
  ///
  /// In it, this message translates to:
  /// **'Il modello sul telefono ha avuto un errore.'**
  String get errorCodeAiLocalEngineError;

  /// No description provided for @errorCodeAiLocalOutOfMemory.
  ///
  /// In it, this message translates to:
  /// **'Memoria insufficiente: scegli un modello più piccolo o un contesto più corto.'**
  String get errorCodeAiLocalOutOfMemory;

  /// No description provided for @errorCodeAiLocalContextTooLong.
  ///
  /// In it, this message translates to:
  /// **'Il testo non entra nel contesto del modello: usa il profilo compatto, un contesto più grande o meno movimenti.'**
  String get errorCodeAiLocalContextTooLong;

  /// No description provided for @errorCodeAiLocalTimeout.
  ///
  /// In it, this message translates to:
  /// **'Il telefono ha impiegato troppo tempo e la generazione è stata interrotta.'**
  String get errorCodeAiLocalTimeout;

  /// No description provided for @errorCodeAiLocalModelMissing.
  ///
  /// In it, this message translates to:
  /// **'Nessun modello installato sul telefono: scaricane uno da Assistente AI.'**
  String get errorCodeAiLocalModelMissing;

  /// No description provided for @errorCodeAiLocalInterrupted.
  ///
  /// In it, this message translates to:
  /// **'La generazione sul telefono si è interrotta.'**
  String get errorCodeAiLocalInterrupted;

  /// No description provided for @errorCodeAiLocalUnsupported.
  ///
  /// In it, this message translates to:
  /// **'Questo dispositivo non può eseguire modelli in locale.'**
  String get errorCodeAiLocalUnsupported;

  /// No description provided for @errorCodeAiLocalTooHot.
  ///
  /// In it, this message translates to:
  /// **'Il telefono è troppo caldo per far girare il modello. Lascialo raffreddare qualche minuto e riprova.'**
  String get errorCodeAiLocalTooHot;

  /// No description provided for @aiModeCloud.
  ///
  /// In it, this message translates to:
  /// **'Cloud'**
  String get aiModeCloud;

  /// No description provided for @aiModeOnDevice.
  ///
  /// In it, this message translates to:
  /// **'Sul dispositivo'**
  String get aiModeOnDevice;

  /// No description provided for @aiLocalModeIntro.
  ///
  /// In it, this message translates to:
  /// **'Il modello gira sul telefono: i tuoi dati non vanno a nessun fornitore AI esterno. Il server prepara i dati e salva report e domande nella cronologia, come per il cloud.'**
  String get aiLocalModeIntro;

  /// No description provided for @aiLocalModelsTitle.
  ///
  /// In it, this message translates to:
  /// **'Modelli sul dispositivo'**
  String get aiLocalModelsTitle;

  /// No description provided for @aiLocalRuntimeTitle.
  ///
  /// In it, this message translates to:
  /// **'Impostazioni di esecuzione'**
  String get aiLocalRuntimeTitle;

  /// No description provided for @aiLocalNoModel.
  ///
  /// In it, this message translates to:
  /// **'Nessun modello attivo. Scaricane uno o importalo per usare l’analisi sul dispositivo.'**
  String get aiLocalNoModel;

  /// No description provided for @aiLocalNoModelShort.
  ///
  /// In it, this message translates to:
  /// **'Nessun modello installato'**
  String get aiLocalNoModelShort;

  /// No description provided for @aiLocalChooseModel.
  ///
  /// In it, this message translates to:
  /// **'Scegli un modello'**
  String get aiLocalChooseModel;

  /// No description provided for @aiLocalNotReadyBody.
  ///
  /// In it, this message translates to:
  /// **'Per analizzare sul telefono serve un modello installato. Scaricane uno da Modelli sul dispositivo.'**
  String get aiLocalNotReadyBody;

  /// No description provided for @aiLocalConsentMenuTitle.
  ///
  /// In it, this message translates to:
  /// **'Informativa sul dispositivo'**
  String get aiLocalConsentMenuTitle;

  /// No description provided for @aiLocalConsentIntro.
  ///
  /// In it, this message translates to:
  /// **'Con l\'analisi sul dispositivo il modello AI gira sul tuo telefono. Prima di ogni analisi vedrai esattamente quali dati gli vengono dati.'**
  String get aiLocalConsentIntro;

  /// No description provided for @aiLocalConsentWhereTitle.
  ///
  /// In it, this message translates to:
  /// **'Dove vengono elaborati i dati'**
  String get aiLocalConsentWhereTitle;

  /// No description provided for @aiLocalConsentWhereBody.
  ///
  /// In it, this message translates to:
  /// **'Sul telefono, senza connessione al modello: nessun fornitore AI esterno riceve i tuoi dati.'**
  String get aiLocalConsentWhereBody;

  /// No description provided for @aiLocalConsentStoredTitle.
  ///
  /// In it, this message translates to:
  /// **'Cosa resta sul server'**
  String get aiLocalConsentStoredTitle;

  /// No description provided for @aiLocalConsentStoredBody.
  ///
  /// In it, this message translates to:
  /// **'Il server prepara il riepilogo dei dati e salva report e domande nella cronologia, così li ritrovi su ogni dispositivo.'**
  String get aiLocalConsentStoredBody;

  /// No description provided for @aiLocalConsentMistakesTitle.
  ///
  /// In it, this message translates to:
  /// **'Il modello può sbagliare'**
  String get aiLocalConsentMistakesTitle;

  /// No description provided for @aiLocalConsentMistakesBody.
  ///
  /// In it, this message translates to:
  /// **'I modelli che girano su un telefono sono piccoli: possono confondere i numeri. Controllali prima di decidere.'**
  String get aiLocalConsentMistakesBody;

  /// No description provided for @aiLocalConsentModelTitle.
  ///
  /// In it, this message translates to:
  /// **'Il modello'**
  String get aiLocalConsentModelTitle;

  /// No description provided for @aiLocalConsentModelBody.
  ///
  /// In it, this message translates to:
  /// **'Lo scarichi da Hugging Face, che vede il tuo indirizzo IP. Ogni modello ha la sua licenza, mostrata prima del download.'**
  String get aiLocalConsentModelBody;

  /// No description provided for @aiSetupStepLocalModel.
  ///
  /// In it, this message translates to:
  /// **'Modello sul telefono'**
  String get aiSetupStepLocalModel;

  /// No description provided for @aiSetupStepLocalModelHint.
  ///
  /// In it, this message translates to:
  /// **'Scarica un modello e accetta l\'informativa sul dispositivo'**
  String get aiSetupStepLocalModelHint;

  /// No description provided for @aiLocalBackendGpu.
  ///
  /// In it, this message translates to:
  /// **'GPU'**
  String get aiLocalBackendGpu;

  /// No description provided for @aiLocalBackendCpu.
  ///
  /// In it, this message translates to:
  /// **'CPU'**
  String get aiLocalBackendCpu;

  /// No description provided for @aiLocalBackendNpu.
  ///
  /// In it, this message translates to:
  /// **'NPU'**
  String get aiLocalBackendNpu;

  /// No description provided for @aiLocalBackendLabel.
  ///
  /// In it, this message translates to:
  /// **'Dove calcola'**
  String get aiLocalBackendLabel;

  /// No description provided for @aiLocalBackendGpuHint.
  ///
  /// In it, this message translates to:
  /// **'Più veloce. Consigliata.'**
  String get aiLocalBackendGpuHint;

  /// No description provided for @aiLocalBackendCpuHint.
  ///
  /// In it, this message translates to:
  /// **'Più lenta e usa più memoria; con LiteRT-LM il contesto arriva al massimo a 8k.'**
  String get aiLocalBackendCpuHint;

  /// No description provided for @aiLocalContextShort.
  ///
  /// In it, this message translates to:
  /// **'contesto {size}'**
  String aiLocalContextShort(String size);

  /// No description provided for @aiLocalOutputShort.
  ///
  /// In it, this message translates to:
  /// **'risposta fino a {count} token'**
  String aiLocalOutputShort(int count);

  /// No description provided for @aiLocalContextLabel.
  ///
  /// In it, this message translates to:
  /// **'Contesto: {count} token'**
  String aiLocalContextLabel(String count);

  /// No description provided for @aiLocalContextHint.
  ///
  /// In it, this message translates to:
  /// **'Quanto testo il modello tiene presente: dati, report e domande.'**
  String get aiLocalContextHint;

  /// No description provided for @aiLocalContextMemoryWarning.
  ///
  /// In it, this message translates to:
  /// **'Più contesto usa più memoria. Se l\'app si chiude durante un\'analisi, riducilo.'**
  String get aiLocalContextMemoryWarning;

  /// No description provided for @aiLocalOutputLabel.
  ///
  /// In it, this message translates to:
  /// **'Risposta massima: {count} token'**
  String aiLocalOutputLabel(String count);

  /// No description provided for @aiLocalOutputHint.
  ///
  /// In it, this message translates to:
  /// **'Un report tipico ne usa 600–1.000. Più spazio alla risposta lascia meno spazio ai dati.'**
  String get aiLocalOutputHint;

  /// No description provided for @aiLocalTemperatureLabel.
  ///
  /// In it, this message translates to:
  /// **'Temperatura: {value}'**
  String aiLocalTemperatureLabel(String value);

  /// No description provided for @aiLocalTemperatureHint.
  ///
  /// In it, this message translates to:
  /// **'Bassa: risposte più fedeli ai numeri. Alta: più varie.'**
  String get aiLocalTemperatureHint;

  /// No description provided for @aiLocalSpeedTitle.
  ///
  /// In it, this message translates to:
  /// **'Velocità'**
  String get aiLocalSpeedTitle;

  /// No description provided for @aiLocalSpeedValue.
  ///
  /// In it, this message translates to:
  /// **'Lettura {prefill} token/s · scrittura {decode} token/s'**
  String aiLocalSpeedValue(String prefill, String decode);

  /// No description provided for @aiLocalSpeedMeasured.
  ///
  /// In it, this message translates to:
  /// **'Misurata su questo telefono'**
  String get aiLocalSpeedMeasured;

  /// No description provided for @aiLocalSpeedCatalog.
  ///
  /// In it, this message translates to:
  /// **'Indicativa, misurata su un Galaxy S26 Ultra'**
  String get aiLocalSpeedCatalog;

  /// No description provided for @aiLocalSpeedFallback.
  ///
  /// In it, this message translates to:
  /// **'Non ancora misurata: stima prudente'**
  String get aiLocalSpeedFallback;

  /// No description provided for @aiLocalMeasure.
  ///
  /// In it, this message translates to:
  /// **'Misura velocità'**
  String get aiLocalMeasure;

  /// No description provided for @aiLocalMeasuring.
  ///
  /// In it, this message translates to:
  /// **'Misura in corso…'**
  String get aiLocalMeasuring;

  /// No description provided for @aiLocalResetDefaults.
  ///
  /// In it, this message translates to:
  /// **'Ripristina i valori predefiniti'**
  String get aiLocalResetDefaults;

  /// No description provided for @aiLocalDeviceTitle.
  ///
  /// In it, this message translates to:
  /// **'Questo telefono'**
  String get aiLocalDeviceTitle;

  /// No description provided for @aiLocalDeviceRam.
  ///
  /// In it, this message translates to:
  /// **'RAM {size}'**
  String aiLocalDeviceRam(String size);

  /// No description provided for @aiLocalDeviceFree.
  ///
  /// In it, this message translates to:
  /// **'{size} liberi'**
  String aiLocalDeviceFree(String size);

  /// No description provided for @aiLocalDeviceUnknown.
  ///
  /// In it, this message translates to:
  /// **'Memoria e spazio non disponibili'**
  String get aiLocalDeviceUnknown;

  /// No description provided for @aiLocalWifiOnly.
  ///
  /// In it, this message translates to:
  /// **'Scarica solo con Wi-Fi'**
  String get aiLocalWifiOnly;

  /// No description provided for @aiLocalWifiOnlyHint.
  ///
  /// In it, this message translates to:
  /// **'I modelli pesano qualche GB: senza Wi-Fi il download aspetta e riprende da solo.'**
  String get aiLocalWifiOnlyHint;

  /// No description provided for @aiLocalPickingFile.
  ///
  /// In it, this message translates to:
  /// **'Preparazione del file…'**
  String get aiLocalPickingFile;

  /// No description provided for @aiLocalImporting.
  ///
  /// In it, this message translates to:
  /// **'Importazione e verifica del modello…'**
  String get aiLocalImporting;

  /// No description provided for @aiLocalInstalledTitle.
  ///
  /// In it, this message translates to:
  /// **'Installati'**
  String get aiLocalInstalledTitle;

  /// No description provided for @aiLocalInUse.
  ///
  /// In it, this message translates to:
  /// **'in uso'**
  String get aiLocalInUse;

  /// No description provided for @aiLocalUnverified.
  ///
  /// In it, this message translates to:
  /// **'non verificato'**
  String get aiLocalUnverified;

  /// No description provided for @aiLocalUseModel.
  ///
  /// In it, this message translates to:
  /// **'Usa questo modello'**
  String get aiLocalUseModel;

  /// No description provided for @aiLocalEngineLitert.
  ///
  /// In it, this message translates to:
  /// **'LiteRT-LM'**
  String get aiLocalEngineLitert;

  /// No description provided for @aiLocalEngineLitertHint.
  ///
  /// In it, this message translates to:
  /// **'Sulla GPU, veloce. Modelli preparati da Google.'**
  String get aiLocalEngineLitertHint;

  /// No description provided for @aiLocalEngineLlama.
  ///
  /// In it, this message translates to:
  /// **'llama.cpp'**
  String get aiLocalEngineLlama;

  /// No description provided for @aiLocalEngineLlamaHint.
  ///
  /// In it, this message translates to:
  /// **'Qualsiasi file GGUF e quantizzazione, sulla CPU: più lento.'**
  String get aiLocalEngineLlamaHint;

  /// No description provided for @aiLocalRecommended.
  ///
  /// In it, this message translates to:
  /// **'Consigliato'**
  String get aiLocalRecommended;

  /// No description provided for @aiLocalRamFits.
  ///
  /// In it, this message translates to:
  /// **'RAM sufficiente'**
  String get aiLocalRamFits;

  /// No description provided for @aiLocalRamTight.
  ///
  /// In it, this message translates to:
  /// **'RAM al limite'**
  String get aiLocalRamTight;

  /// No description provided for @aiLocalRamInsufficient.
  ///
  /// In it, this message translates to:
  /// **'RAM insufficiente'**
  String get aiLocalRamInsufficient;

  /// No description provided for @aiLocalRamUnknown.
  ///
  /// In it, this message translates to:
  /// **'RAM non nota'**
  String get aiLocalRamUnknown;

  /// No description provided for @aiLocalRamWarningTitle.
  ///
  /// In it, this message translates to:
  /// **'Memoria insufficiente'**
  String get aiLocalRamWarningTitle;

  /// No description provided for @aiLocalRamWarningMessage.
  ///
  /// In it, this message translates to:
  /// **'Questo telefono ha meno RAM di quella che serve al modello: potrebbe non partire o far chiudere l\'app.'**
  String get aiLocalRamWarningMessage;

  /// No description provided for @aiLocalDownloadAnyway.
  ///
  /// In it, this message translates to:
  /// **'Scarica comunque'**
  String get aiLocalDownloadAnyway;

  /// No description provided for @aiLocalDownload.
  ///
  /// In it, this message translates to:
  /// **'Scarica'**
  String get aiLocalDownload;

  /// No description provided for @aiLocalProgress.
  ///
  /// In it, this message translates to:
  /// **'{done} di {total}'**
  String aiLocalProgress(String done, String total);

  /// No description provided for @aiLocalQueued.
  ///
  /// In it, this message translates to:
  /// **'In coda'**
  String get aiLocalQueued;

  /// No description provided for @aiLocalPaused.
  ///
  /// In it, this message translates to:
  /// **'In pausa · {progress}'**
  String aiLocalPaused(String progress);

  /// No description provided for @aiLocalWaitingForWifi.
  ///
  /// In it, this message translates to:
  /// **'In attesa del Wi-Fi'**
  String get aiLocalWaitingForWifi;

  /// No description provided for @aiLocalVerifying.
  ///
  /// In it, this message translates to:
  /// **'Verifica del file…'**
  String get aiLocalVerifying;

  /// No description provided for @aiLocalPause.
  ///
  /// In it, this message translates to:
  /// **'Pausa'**
  String get aiLocalPause;

  /// No description provided for @aiLocalResume.
  ///
  /// In it, this message translates to:
  /// **'Riprendi'**
  String get aiLocalResume;

  /// No description provided for @aiLocalRetry.
  ///
  /// In it, this message translates to:
  /// **'Riprova'**
  String get aiLocalRetry;

  /// No description provided for @aiLocalCancel.
  ///
  /// In it, this message translates to:
  /// **'Annulla'**
  String get aiLocalCancel;

  /// No description provided for @aiLocalLicenseBody.
  ///
  /// In it, this message translates to:
  /// **'Il file pesa {size} e viene scaricato da Hugging Face. Il modello è distribuito con licenza {license}: scaricandolo la accetti.'**
  String aiLocalLicenseBody(String size, String license);

  /// No description provided for @aiLocalGatedBody.
  ///
  /// In it, this message translates to:
  /// **'Questo modello è riservato: accetta la licenza sulla sua pagina Hugging Face e inserisci un token di lettura.'**
  String get aiLocalGatedBody;

  /// No description provided for @aiLocalAcceptAndDownload.
  ///
  /// In it, this message translates to:
  /// **'Accetta e scarica'**
  String get aiLocalAcceptAndDownload;

  /// No description provided for @aiLocalDeleteTitle.
  ///
  /// In it, this message translates to:
  /// **'Eliminare il modello?'**
  String get aiLocalDeleteTitle;

  /// No description provided for @aiLocalDeleteMessage.
  ///
  /// In it, this message translates to:
  /// **'{name} verrà rimosso dal telefono. Le analisi già fatte restano nella cronologia.'**
  String aiLocalDeleteMessage(String name);

  /// No description provided for @aiLocalDeleted.
  ///
  /// In it, this message translates to:
  /// **'Modello eliminato: liberati {size}'**
  String aiLocalDeleted(String size);

  /// No description provided for @aiLocalImportFile.
  ///
  /// In it, this message translates to:
  /// **'Importa un file'**
  String get aiLocalImportFile;

  /// No description provided for @aiLocalImportUrl.
  ///
  /// In it, this message translates to:
  /// **'Scarica da URL'**
  String get aiLocalImportUrl;

  /// No description provided for @aiLocalImportAction.
  ///
  /// In it, this message translates to:
  /// **'Importa'**
  String get aiLocalImportAction;

  /// No description provided for @aiLocalUrlLabel.
  ///
  /// In it, this message translates to:
  /// **'Indirizzo https del file'**
  String get aiLocalUrlLabel;

  /// No description provided for @aiLocalNameLabel.
  ///
  /// In it, this message translates to:
  /// **'Nome del modello'**
  String get aiLocalNameLabel;

  /// No description provided for @aiLocalQuantLabel.
  ///
  /// In it, this message translates to:
  /// **'Quantizzazione (es. Q4_K_M)'**
  String get aiLocalQuantLabel;

  /// No description provided for @aiLocalShaLabel.
  ///
  /// In it, this message translates to:
  /// **'SHA-256 (facoltativo)'**
  String get aiLocalShaLabel;

  /// No description provided for @aiLocalShaHelper.
  ///
  /// In it, this message translates to:
  /// **'Se lo inserisci, il file viene verificato; altrimenti il modello resta \"non verificato\".'**
  String get aiLocalShaHelper;

  /// No description provided for @aiLocalShaInvalid.
  ///
  /// In it, this message translates to:
  /// **'Deve avere 64 caratteri esadecimali.'**
  String get aiLocalShaInvalid;

  /// No description provided for @aiLocalImported.
  ///
  /// In it, this message translates to:
  /// **'{name} importato'**
  String aiLocalImported(String name);

  /// No description provided for @aiLocalImportedUnverified.
  ///
  /// In it, this message translates to:
  /// **'{name} importato, non verificato'**
  String aiLocalImportedUnverified(String name);

  /// No description provided for @aiLocalTokenAction.
  ///
  /// In it, this message translates to:
  /// **'Token Hugging Face'**
  String get aiLocalTokenAction;

  /// No description provided for @aiLocalTokenLabel.
  ///
  /// In it, this message translates to:
  /// **'Token di lettura'**
  String get aiLocalTokenLabel;

  /// No description provided for @aiLocalTokenHelper.
  ///
  /// In it, this message translates to:
  /// **'Serve solo per i modelli riservati. Resta sul telefono e viene inviato solo a huggingface.co.'**
  String get aiLocalTokenHelper;

  /// No description provided for @aiLocalTokenStored.
  ///
  /// In it, this message translates to:
  /// **'Un token è salvato su questo telefono.'**
  String get aiLocalTokenStored;

  /// No description provided for @aiLocalTokenNone.
  ///
  /// In it, this message translates to:
  /// **'Nessun token salvato.'**
  String get aiLocalTokenNone;

  /// No description provided for @aiLocalTokenSaved.
  ///
  /// In it, this message translates to:
  /// **'Token salvato'**
  String get aiLocalTokenSaved;

  /// No description provided for @aiLocalTokenRemoved.
  ///
  /// In it, this message translates to:
  /// **'Token rimosso'**
  String get aiLocalTokenRemoved;

  /// No description provided for @aiCompactProfile.
  ///
  /// In it, this message translates to:
  /// **'Profilo compatto'**
  String get aiCompactProfile;

  /// No description provided for @aiCompactProfileHint.
  ///
  /// In it, this message translates to:
  /// **'Meno dettagli e regole più brevi: un prompt più corto.'**
  String get aiCompactProfileHint;

  /// No description provided for @aiCompactProfileHintLocal.
  ///
  /// In it, this message translates to:
  /// **'Consigliato sul telefono: meno dettagli, regole più brevi e un prompt che entra nel contesto del modello.'**
  String get aiCompactProfileHintLocal;

  /// No description provided for @aiPreviewOnDevice.
  ///
  /// In it, this message translates to:
  /// **'Elaborato sul telefono con {model}'**
  String aiPreviewOnDevice(String model);

  /// No description provided for @aiPreviewNoCost.
  ///
  /// In it, this message translates to:
  /// **'Nessun costo'**
  String get aiPreviewNoCost;

  /// No description provided for @aiPreviewCompacted.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{Un dettaglio è stato ridotto per stare nel limite.} other{{count} dettagli sono stati ridotti per stare nel limite.}}'**
  String aiPreviewCompacted(int count);

  /// No description provided for @aiRunOnDeviceAction.
  ///
  /// In it, this message translates to:
  /// **'Avvia sul telefono'**
  String get aiRunOnDeviceAction;

  /// No description provided for @aiLocalContextUse.
  ///
  /// In it, this message translates to:
  /// **'Contesto: {used} di {total} token'**
  String aiLocalContextUse(String used, String total);

  /// No description provided for @aiLocalContextParts.
  ///
  /// In it, this message translates to:
  /// **'dati {input} · risposta {output}'**
  String aiLocalContextParts(String input, String output);

  /// No description provided for @aiLocalCountExact.
  ///
  /// In it, this message translates to:
  /// **'conteggio esatto'**
  String get aiLocalCountExact;

  /// No description provided for @aiLocalCountEstimated.
  ///
  /// In it, this message translates to:
  /// **'stima'**
  String get aiLocalCountEstimated;

  /// No description provided for @aiLocalContextTight.
  ///
  /// In it, this message translates to:
  /// **'Quasi pieno: le domande successive avranno poco spazio.'**
  String get aiLocalContextTight;

  /// No description provided for @aiLocalContextOverflow.
  ///
  /// In it, this message translates to:
  /// **'Non entra nel contesto del modello. Prova una di queste soluzioni:'**
  String get aiLocalContextOverflow;

  /// No description provided for @aiLocalFixCompact.
  ///
  /// In it, this message translates to:
  /// **'Profilo compatto'**
  String get aiLocalFixCompact;

  /// No description provided for @aiLocalFixFewerTransactions.
  ///
  /// In it, this message translates to:
  /// **'Meno movimenti'**
  String get aiLocalFixFewerTransactions;

  /// No description provided for @aiLocalFixShorterAnswer.
  ///
  /// In it, this message translates to:
  /// **'Risposta più corta'**
  String get aiLocalFixShorterAnswer;

  /// No description provided for @aiLocalFixLargerContext.
  ///
  /// In it, this message translates to:
  /// **'Contesto più grande'**
  String get aiLocalFixLargerContext;

  /// No description provided for @aiLocalTimeEstimate.
  ///
  /// In it, this message translates to:
  /// **'Tempo stimato: {low}–{high}'**
  String aiLocalTimeEstimate(String low, String high);

  /// No description provided for @aiLocalTimeRough.
  ///
  /// In it, this message translates to:
  /// **'Stima approssimativa: misura la velocità in Impostazioni di esecuzione.'**
  String get aiLocalTimeRough;

  /// No description provided for @aiLocalWarnWarm.
  ///
  /// In it, this message translates to:
  /// **'Il telefono è caldo: sarà più lento.'**
  String get aiLocalWarnWarm;

  /// No description provided for @aiLocalWarnBattery.
  ///
  /// In it, this message translates to:
  /// **'Batteria sotto il 15%: collega il caricatore.'**
  String get aiLocalWarnBattery;

  /// No description provided for @aiLocalWarnMemory.
  ///
  /// In it, this message translates to:
  /// **'Poca memoria libera: chiudi le altre app se l\'analisi si interrompe.'**
  String get aiLocalWarnMemory;

  /// No description provided for @aiLocalKeepOpen.
  ///
  /// In it, this message translates to:
  /// **'Il telefono sta scrivendo. Puoi uscire dall\'app: ti avvisiamo quando ha finito.'**
  String get aiLocalKeepOpen;

  /// No description provided for @aiLocalTokensPerSecond.
  ///
  /// In it, this message translates to:
  /// **'{value} token/s'**
  String aiLocalTokensPerSecond(String value);

  /// No description provided for @errorCodeAiLocalDownloadNetwork.
  ///
  /// In it, this message translates to:
  /// **'Download interrotto dalla rete: riprendi quando la connessione torna.'**
  String get errorCodeAiLocalDownloadNetwork;

  /// No description provided for @errorCodeAiLocalDownloadGated.
  ///
  /// In it, this message translates to:
  /// **'Modello riservato: accetta la licenza su Hugging Face e inserisci un token valido.'**
  String get errorCodeAiLocalDownloadGated;

  /// No description provided for @errorCodeAiLocalDownloadNotFound.
  ///
  /// In it, this message translates to:
  /// **'File non trovato sul server.'**
  String get errorCodeAiLocalDownloadNotFound;

  /// No description provided for @errorCodeAiLocalDownloadHttp.
  ///
  /// In it, this message translates to:
  /// **'Il server ha rifiutato il download.'**
  String get errorCodeAiLocalDownloadHttp;

  /// No description provided for @errorCodeAiLocalDownloadNoSpace.
  ///
  /// In it, this message translates to:
  /// **'Spazio insufficiente sul telefono per questo modello.'**
  String get errorCodeAiLocalDownloadNoSpace;

  /// No description provided for @errorCodeAiLocalDownloadChecksum.
  ///
  /// In it, this message translates to:
  /// **'Il file scaricato non corrisponde a quello atteso ed è stato scartato.'**
  String get errorCodeAiLocalDownloadChecksum;

  /// No description provided for @errorCodeAiLocalDownloadInsecureUrl.
  ///
  /// In it, this message translates to:
  /// **'L\'indirizzo deve iniziare con https://.'**
  String get errorCodeAiLocalDownloadInsecureUrl;

  /// No description provided for @errorCodeAiLocalImportUnknownFormat.
  ///
  /// In it, this message translates to:
  /// **'Formato non riconosciuto: servono file .gguf o .litertlm.'**
  String get errorCodeAiLocalImportUnknownFormat;

  /// No description provided for @aiFeaturesSwitchTitle.
  ///
  /// In it, this message translates to:
  /// **'Funzioni AI'**
  String get aiFeaturesSwitchTitle;

  /// No description provided for @aiFeaturesSwitchSubtitle.
  ///
  /// In it, this message translates to:
  /// **'Assistente AI, analisi nei Report e in Cronologia, scopo dei portafogli. Spegnendole non si cancella nulla: analisi, chiavi e modelli restano dove sono.'**
  String get aiFeaturesSwitchSubtitle;

  /// No description provided for @aiRunModelLabel.
  ///
  /// In it, this message translates to:
  /// **'Modello'**
  String get aiRunModelLabel;

  /// No description provided for @aiPendingTitle.
  ///
  /// In it, this message translates to:
  /// **'Risposte non inviate'**
  String get aiPendingTitle;

  /// No description provided for @aiPendingIntro.
  ///
  /// In it, this message translates to:
  /// **'Report e risposte scritti su questo telefono che il server non ha ancora: la rete mancava quando sono finiti, oppure il server li ha rifiutati. Restano qui finché chi li ha scritti non li invia o li elimina. Chiunque usi l\'app su questo telefono può leggerli.'**
  String get aiPendingIntro;

  /// No description provided for @aiPendingEmpty.
  ///
  /// In it, this message translates to:
  /// **'Nessuna risposta in attesa: il server ha tutto.'**
  String get aiPendingEmpty;

  /// No description provided for @aiPendingReport.
  ///
  /// In it, this message translates to:
  /// **'Report'**
  String get aiPendingReport;

  /// No description provided for @aiPendingAnswer.
  ///
  /// In it, this message translates to:
  /// **'Risposta a una domanda'**
  String get aiPendingAnswer;

  /// No description provided for @aiPendingUnknownOwner.
  ///
  /// In it, this message translates to:
  /// **'account sconosciuto'**
  String get aiPendingUnknownOwner;

  /// No description provided for @aiPendingWaiting.
  ///
  /// In it, this message translates to:
  /// **'In attesa di invio: parte da sola quando l\'autore accede o riapre l\'app.'**
  String get aiPendingWaiting;

  /// No description provided for @aiPendingRefused.
  ///
  /// In it, this message translates to:
  /// **'Rifiutato dal server: {reason}'**
  String aiPendingRefused(String reason);

  /// No description provided for @aiPendingResend.
  ///
  /// In it, this message translates to:
  /// **'Invia ora'**
  String get aiPendingResend;

  /// No description provided for @aiPendingSent.
  ///
  /// In it, this message translates to:
  /// **'Inviato: ora è nella cronologia.'**
  String get aiPendingSent;

  /// No description provided for @aiPendingRefusedAgain.
  ///
  /// In it, this message translates to:
  /// **'Il server lo rifiuta ancora: puoi leggerlo qui o eliminarlo.'**
  String get aiPendingRefusedAgain;

  /// No description provided for @aiPendingNotOwner.
  ///
  /// In it, this message translates to:
  /// **'Solo chi lo ha scritto può inviarlo.'**
  String get aiPendingNotOwner;

  /// No description provided for @aiPendingOwnerOnly.
  ///
  /// In it, this message translates to:
  /// **'Solo {owner} può inviarlo o eliminarlo.'**
  String aiPendingOwnerOnly(String owner);

  /// No description provided for @aiPendingDeleteTitle.
  ///
  /// In it, this message translates to:
  /// **'Eliminare questa risposta?'**
  String get aiPendingDeleteTitle;

  /// No description provided for @aiPendingDeleteMessage.
  ///
  /// In it, this message translates to:
  /// **'Il testo esiste solo su questo telefono: eliminandolo va perso.'**
  String get aiPendingDeleteMessage;

  /// No description provided for @aiPendingBanner.
  ///
  /// In it, this message translates to:
  /// **'{count, plural, =1{Una risposta scritta sul telefono non è ancora sul server} other{{count} risposte scritte sul telefono non sono ancora sul server}}'**
  String aiPendingBanner(int count);

  /// No description provided for @aiLocalFollowUpUnsupported.
  ///
  /// In it, this message translates to:
  /// **'Questa analisi è stata scritta sul telefono: continua le domande da un telefono Android con un modello installato.'**
  String get aiLocalFollowUpUnsupported;

  /// No description provided for @aiLocalFollowUpNoModel.
  ///
  /// In it, this message translates to:
  /// **'Per rispondere serve un modello sul telefono: installane uno da Modelli sul dispositivo.'**
  String get aiLocalFollowUpNoModel;

  /// No description provided for @aiLocalFollowUpOtherModel.
  ///
  /// In it, this message translates to:
  /// **'Il modello del report ({report}) non è più installato: risponderà {current}.'**
  String aiLocalFollowUpOtherModel(String report, String current);

  /// No description provided for @bgWorkTitle.
  ///
  /// In it, this message translates to:
  /// **'Analisi AI sul dispositivo'**
  String get bgWorkTitle;

  /// No description provided for @bgWorkChannel.
  ///
  /// In it, this message translates to:
  /// **'Attività in corso'**
  String get bgWorkChannel;

  /// No description provided for @bgWorkStop.
  ///
  /// In it, this message translates to:
  /// **'Interrompi'**
  String get bgWorkStop;

  /// No description provided for @bgDownloading.
  ///
  /// In it, this message translates to:
  /// **'Download {name} · {percent}%'**
  String bgDownloading(String name, int percent);

  /// No description provided for @bgVerifying.
  ///
  /// In it, this message translates to:
  /// **'Verifica di {name}'**
  String bgVerifying(String name);

  /// No description provided for @bgWaitingWifi.
  ///
  /// In it, this message translates to:
  /// **'{name} · in attesa del Wi-Fi'**
  String bgWaitingWifi(String name);

  /// No description provided for @bgQueued.
  ///
  /// In it, this message translates to:
  /// **'{name} · in coda'**
  String bgQueued(String name);

  /// No description provided for @aiNotifyChannel.
  ///
  /// In it, this message translates to:
  /// **'Analisi AI'**
  String get aiNotifyChannel;

  /// No description provided for @notifyModelReadyTitle.
  ///
  /// In it, this message translates to:
  /// **'Modello pronto'**
  String get notifyModelReadyTitle;

  /// No description provided for @notifyModelReadyBody.
  ///
  /// In it, this message translates to:
  /// **'{name} è installato: puoi usarlo per le analisi.'**
  String notifyModelReadyBody(String name);

  /// No description provided for @notifyDownloadFailedTitle.
  ///
  /// In it, this message translates to:
  /// **'Download non riuscito'**
  String get notifyDownloadFailedTitle;

  /// No description provided for @aiLeaveTitle.
  ///
  /// In it, this message translates to:
  /// **'L\'analisi è ancora in corso'**
  String get aiLeaveTitle;

  /// No description provided for @aiLeaveBody.
  ///
  /// In it, this message translates to:
  /// **'Il telefono sta ancora scrivendo. Puoi interromperla (il testo scritto finora viene salvato), restare qui o lasciarla continuare in background: ti avvisiamo con una notifica quando ha finito.'**
  String get aiLeaveBody;

  /// No description provided for @aiLeaveStop.
  ///
  /// In it, this message translates to:
  /// **'Interrompi'**
  String get aiLeaveStop;

  /// No description provided for @aiLeaveStay.
  ///
  /// In it, this message translates to:
  /// **'Resta'**
  String get aiLeaveStay;

  /// No description provided for @aiLeaveBackground.
  ///
  /// In it, this message translates to:
  /// **'Continua in background'**
  String get aiLeaveBackground;

  /// No description provided for @bgWritingReport.
  ///
  /// In it, this message translates to:
  /// **'Scrittura del report · {words} parole'**
  String bgWritingReport(int words);

  /// No description provided for @bgWritingAnswer.
  ///
  /// In it, this message translates to:
  /// **'Scrittura della risposta · {words} parole'**
  String bgWritingAnswer(int words);

  /// No description provided for @notifyReportReadyTitle.
  ///
  /// In it, this message translates to:
  /// **'Analisi pronta'**
  String get notifyReportReadyTitle;

  /// No description provided for @notifyAnswerReadyTitle.
  ///
  /// In it, this message translates to:
  /// **'Risposta pronta'**
  String get notifyAnswerReadyTitle;

  /// No description provided for @notifyAnalysisFailedTitle.
  ///
  /// In it, this message translates to:
  /// **'Analisi interrotta'**
  String get notifyAnalysisFailedTitle;

  /// No description provided for @notifyAnalysisFallbackBody.
  ///
  /// In it, this message translates to:
  /// **'Tocca per leggerla.'**
  String get notifyAnalysisFallbackBody;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'it'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'it':
      return AppLocalizationsIt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
