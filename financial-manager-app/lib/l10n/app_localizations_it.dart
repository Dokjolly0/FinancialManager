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
}
