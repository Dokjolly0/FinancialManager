import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../account/presentation/view_models/account_providers.dart';
import '../../data/providers.dart';

/// Confirms the email address from the link in the verification email
/// (`/verify-email?token=...`). Runs once per token while the screen is
/// open: a token is single-use, so a second call would always fail.
final verifyEmailProvider = FutureProvider.autoDispose.family<void, String>((
  ref,
  token,
) async {
  await ref.read(authRepositoryProvider).verifyEmail(token);
  // The profile shows the green check once it's reloaded.
  ref.invalidate(accountProfileProvider);
});
