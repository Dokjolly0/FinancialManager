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
  /// **'Tema, fuso orario, lingua, saldo'**
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

  /// No description provided for @exportSavedMessage.
  ///
  /// In it, this message translates to:
  /// **'Esportazione salvata in {path}'**
  String exportSavedMessage(String path);

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
  /// **'CSV per le operazioni, JSON per profilo, portafoglio, categorie, modelli e operazioni.'**
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
