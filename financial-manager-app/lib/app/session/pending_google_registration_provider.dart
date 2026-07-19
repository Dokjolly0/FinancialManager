import 'package:flutter_riverpod/legacy.dart';

import '../../features/authentication/domain/models/google_sign_in_outcome.dart';

/// Holds the ticket + prefill data between the Google sign-in call and the
/// registration-completion screen (plan.md section 7.4, 8.2) — simpler
/// than threading it through go_router's `extra` for a value that's only
/// ever set right before navigating to the one screen that reads it.
final pendingGoogleRegistrationProvider =
    StateProvider<GoogleSignInRegistrationRequired?>((ref) => null);
