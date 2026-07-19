import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/account/presentation/view_models/account_providers.dart';
import '../../features/account/presentation/view_models/linked_accounts_controller.dart';
import '../../features/categories/data/providers.dart';
import '../../features/history/presentation/view_models/history_controller.dart';
import '../../features/home/presentation/view_models/home_controller.dart';
import '../../features/reports/presentation/view_models/report_controller.dart';

/// Providers caching data scoped to the signed-in account, whose build()
/// only runs once per provider lifetime (none are .autoDispose, and the
/// app's single ProviderScope from bootstrap.dart is never recreated).
/// Invalidated together by SessionController on every sign-in and sign-out
/// so no screen can show a previous session's data after a user switch.
/// New per-account caches should be added here. currentUserProvider is
/// deliberately NOT included — SessionController manages it directly since
/// it must be set to the new user (login) or explicitly cleared (logout),
/// not just reset to its build()-time default.
///
/// Guarded with ref.exists: ref.invalidate would otherwise force-create a
/// provider that was never read (running its build(), which for several of
/// these eagerly fires an HTTP fetch) just to immediately re-invalidate it —
/// wasteful, and actively harmful right after sign-out/a failed session
/// restore, when there's no authenticated user to fetch data for yet.
void invalidateUserScopedProviders(Ref ref) {
  void invalidateIfExists(ProviderBase provider) {
    if (ref.exists(provider)) ref.invalidate(provider);
  }

  invalidateIfExists(homeControllerProvider);
  invalidateIfExists(historyControllerProvider);
  invalidateIfExists(reportControllerProvider);
  invalidateIfExists(categoriesProvider);
  invalidateIfExists(accountProfileProvider);
  invalidateIfExists(accountWalletProvider);
  invalidateIfExists(linkedAccountsControllerProvider);
}
