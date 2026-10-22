import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/account/presentation/view_models/account_providers.dart';
import '../features/ai/data/providers.dart';
import '../l10n/app_localizations.dart';
import 'router.dart';
import 'session/session_controller.dart';
import 'session/session_status.dart';

/// Opens the screen of a tapped AI notification (plan.md section 33.9),
/// also one that launched the app: once the session is authenticated and
/// the AI features are on. Watched by the root widget.
final aiNotificationRoutingProvider = Provider<void>((ref) {
  String? pending;

  void open() {
    final route = pending;
    if (route == null) return;
    if (ref.read(sessionControllerProvider) != SessionStatus.authenticated) {
      return;
    }
    final profile = ref.read(accountProfileProvider).value;
    if (profile == null) {
      ref
          .read(accountProfileProvider.future)
          .then((_) => open(), onError: (_) {});
      return;
    }
    pending = null;
    if (!profile.aiEnabled) return;
    ref.read(appRouterProvider).push(route);
  }

  ref.listen(sessionControllerProvider, (_, _) => open());
  // Nothing account-bound yet: the channel takes the phone's language.
  final phone = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
  final l10n = lookupAppLocalizations(Locale(phone == 'en' ? 'en' : 'it'));
  ref
      .read(aiNotifierProvider)
      .init(
        channelName: l10n.aiNotifyChannel,
        onOpen: (route) {
          pending = route;
          open();
        },
      )
      .catchError((_) {});
});
