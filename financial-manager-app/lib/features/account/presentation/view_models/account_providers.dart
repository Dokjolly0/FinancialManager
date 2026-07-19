import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../transactions/data/providers.dart';
import '../../../transactions/domain/models/wallet.dart';
import '../../data/providers.dart';
import '../../domain/models/user_profile.dart';

/// Cached profile, shared by every Account sub-screen (hub, profilo,
/// sicurezza, preferenze). Mirrors categoriesProvider's pattern: mutating
/// screens call `ref.invalidate(accountProfileProvider)` after a
/// successful write instead of managing their own copy of this state.
final accountProfileProvider = FutureProvider<UserProfile>((ref) {
  return ref.watch(accountRepositoryProvider).getProfile();
});

/// Cached wallet, shown on the Account hub's "Portafoglio" section.
final accountWalletProvider = FutureProvider<Wallet>((ref) {
  return ref.watch(walletRepositoryProvider).getWallet();
});
