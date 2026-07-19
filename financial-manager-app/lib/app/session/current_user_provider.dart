import 'package:flutter_riverpod/legacy.dart';

import '../../features/authentication/domain/models/auth_user.dart';

/// The currently authenticated user's basic info, set on successful
/// login/register/session-restore and cleared on sign-out. Read-heavy
/// screens (home greeting, account) watch this instead of re-fetching
/// `/v1/me` on every navigation.
final currentUserProvider = StateProvider<AuthUser?>((ref) => null);
