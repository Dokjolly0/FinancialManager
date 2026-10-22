import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/models/user_profile.dart';

/// Cached profile, shared by every Account sub-screen (hub, profilo,
/// sicurezza, preferenze). Mirrors categoriesProvider's pattern: mutating
/// screens call `ref.invalidate(accountProfileProvider)` after a
/// successful write instead of managing their own copy of this state.
final accountProfileProvider = FutureProvider<UserProfile>((ref) {
  return ref.watch(accountRepositoryProvider).getProfile();
});

/// Whether the AI features show (Preferences → Funzioni AI, plan.md
/// section 32.10). False until the profile is known, so a user who turned
/// them off never sees them flash in.
final aiFeaturesEnabledProvider = Provider<bool>(
  (ref) => ref.watch(accountProfileProvider).value?.aiEnabled ?? false,
);
