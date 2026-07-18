import 'package:google_sign_in/google_sign_in.dart';

/// Thrown when the user dismisses the Google account picker — not a
/// failure, just "nothing happened."
class GoogleSignInCancelled implements Exception {
  const GoogleSignInCancelled();
}

/// Wraps `google_sign_in` v7's singleton API behind a minimal surface: get
/// an ID token, or sign out. Everything else (scopes, authorization,
/// server auth codes) is out of scope — the backend only needs the ID
/// token to verify identity (plan.md section 15.2).
///
/// serverClientId is the Web-application OAuth client (the one the
/// backend verifies tokens against, via GOOGLE_CLIENT_IDS). It is not a
/// secret — Google OAuth client IDs are meant to be embedded in client
/// apps — but Android/iOS still need their own platform-specific OAuth
/// clients registered in Google Cloud Console (SHA-1 for Android, bundle
/// ID for iOS) before the native sign-in flow will succeed; that
/// registration is a manual Cloud Console step, not something this code
/// can do.
class GoogleSignInService {
  GoogleSignInService({
    this.serverClientId =
        '394336083524-bulv3lv21sl2jl1gkrjnad25i7qvgv1v.apps.googleusercontent.com',
  });

  final String serverClientId;
  bool _initialized = false;

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    await GoogleSignIn.instance.initialize(serverClientId: serverClientId);
    _initialized = true;
  }

  /// Triggers the sign-in UI and returns the Google ID token to send to
  /// the backend. Throws [GoogleSignInCancelled] if the user dismisses the
  /// picker, or rethrows any other [GoogleSignInException].
  Future<String> signIn() async {
    await _ensureInitialized();

    final GoogleSignInAccount account;
    try {
      account = await GoogleSignIn.instance.authenticate();
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const GoogleSignInCancelled();
      }
      rethrow;
    }

    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw StateError('Google non ha restituito un ID token.');
    }
    return idToken;
  }

  Future<void> signOut() async {
    await _ensureInitialized();
    await GoogleSignIn.instance.signOut();
  }
}
