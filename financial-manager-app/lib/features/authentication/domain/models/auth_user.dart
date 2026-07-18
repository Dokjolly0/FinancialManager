/// The authenticated principal (plan.md section 4.1: "identità applicativa,
/// indipendente dal metodo di autenticazione"). Wallet/balance data is
/// fetched separately by the wallet feature — this model only carries what
/// the auth flows themselves need.
class AuthUser {
  const AuthUser({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.username,
    required this.email,
    required this.emailVerified,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String username;
  final String email;
  final bool emailVerified;
}
