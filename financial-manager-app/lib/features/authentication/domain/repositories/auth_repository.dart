import '../models/auth_user.dart';
import '../models/google_sign_in_outcome.dart';

/// Parameters for registration (plan.md section 7.3). Kept as a single
/// bag rather than positional args since the 3-step wizard collects these
/// across separate screens.
class RegisterParams {
  const RegisterParams({
    required this.firstName,
    required this.lastName,
    required this.username,
    required this.email,
    required this.password,
    required this.confirmPassword,
    required this.avatarBackgroundColor,
    required this.avatarTextColor,
    required this.initialBalanceMinor,
    required this.currency,
    required this.timezone,
    required this.locale,
    required this.acceptedTerms,
  });

  final String firstName;
  final String lastName;
  final String username;
  final String email;
  final String password;
  final String confirmPassword;
  final String avatarBackgroundColor;
  final String avatarTextColor;
  final int initialBalanceMinor;
  final String currency;
  final String timezone;
  final String locale;
  final bool acceptedTerms;
}

/// Parameters for completing registration after a Google ticket (plan.md
/// section 7.4). Password is optional — Google-only accounts are allowed.
class GoogleCompletionParams {
  const GoogleCompletionParams({
    required this.ticket,
    required this.username,
    this.password = '',
    this.confirmPassword = '',
    required this.avatarBackgroundColor,
    required this.avatarTextColor,
    required this.initialBalanceMinor,
    required this.currency,
    required this.timezone,
    required this.locale,
    required this.acceptedTerms,
  });

  final String ticket;
  final String username;
  final String password;
  final String confirmPassword;
  final String avatarBackgroundColor;
  final String avatarTextColor;
  final int initialBalanceMinor;
  final String currency;
  final String timezone;
  final String locale;
  final bool acceptedTerms;
}

/// Domain-facing authentication operations (plan.md section 14.1). The
/// presentation layer depends only on this interface, never on Dio or the
/// backend's JSON shape directly.
abstract class AuthRepository {
  Future<AuthUser> register(RegisterParams params);

  Future<AuthUser> login({
    required String usernameOrEmail,
    required String password,
  });

  /// Runs the native Google sign-in flow and verifies the resulting ID
  /// token with the backend (plan.md section 8.2).
  Future<GoogleSignInOutcome> signInWithGoogle();

  Future<AuthUser> completeGoogleRegistration(GoogleCompletionParams params);

  Future<void> logout();

  Future<void> logoutAll();

  /// Attempts to restore a session from the stored refresh token at app
  /// startup (plan.md section 7.1). Returns the restored user, or null if
  /// there was no session to restore or it could not be restored.
  Future<AuthUser?> tryRestoreSession();

  Future<void> forgotPassword(String email);

  Future<void> resetPassword({
    required String token,
    required String newPassword,
  });

  Future<void> verifyEmail(String token);

  Future<void> resendVerification();
}
