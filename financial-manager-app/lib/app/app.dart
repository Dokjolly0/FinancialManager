import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/account/presentation/view_models/account_providers.dart';
import '../l10n/app_localizations.dart';
import 'router.dart';
import 'session/session_controller.dart';
import 'session/session_status.dart';
import 'theme/app_theme.dart';

/// Root widget. Composes routing, theming (light/dark, section 6.3), and
/// localization (English source with an Italian translation, section
/// 3.1/9.2). Theme and language follow the signed-in user's saved
/// preference (section 7.13) once authenticated; before that — or if the
/// preference hasn't loaded yet — they fall back to the system default.
class FinancialManagerApp extends ConsumerWidget {
  const FinancialManagerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final isAuthenticated =
        ref.watch(sessionControllerProvider) == SessionStatus.authenticated;
    final profile = isAuthenticated
        ? ref.watch(accountProfileProvider).value
        : null;

    return MaterialApp.router(
      onGenerateTitle: (context) => AppLocalizations.of(context).appTitle,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: switch (profile?.theme) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      },
      // null falls back to resolving from the system locale (MaterialApp's
      // documented default), matching pre-login/no-preference-yet behavior.
      locale: profile == null ? null : Locale(profile.locale.split('-').first),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: router,
    );
  }
}
