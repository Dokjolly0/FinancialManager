import 'auth_user.dart';

/// The two branches of plan.md section 8.2's flowchart, plus a third
/// outcome the flowchart doesn't need to model: the user simply dismissed
/// the Google account picker.
sealed class GoogleSignInOutcome {
  const GoogleSignInOutcome();
}

class GoogleSignInAuthenticated extends GoogleSignInOutcome {
  const GoogleSignInAuthenticated(this.user);
  final AuthUser user;
}

/// The Google identity isn't linked to any account yet — the caller must
/// navigate to the registration-completion screen with this ticket.
class GoogleSignInRegistrationRequired extends GoogleSignInOutcome {
  const GoogleSignInRegistrationRequired({
    required this.ticket,
    required this.email,
    required this.emailVerified,
    required this.suggestedFirstName,
    required this.suggestedLastName,
  });

  final String ticket;
  final String email;
  final bool emailVerified;
  final String suggestedFirstName;
  final String suggestedLastName;
}

class GoogleSignInCancelledByUser extends GoogleSignInOutcome {
  const GoogleSignInCancelledByUser();
}
