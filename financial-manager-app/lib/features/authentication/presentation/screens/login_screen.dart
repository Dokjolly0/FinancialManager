import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../app/session/pending_google_registration_provider.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/error_code_localizations.dart';
import '../../../../core/errors/error_presentation.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/models/google_sign_in_outcome.dart';
import '../view_models/google_sign_in_controller.dart';
import '../view_models/login_controller.dart';
import '../widgets/password_field.dart';

/// Login screen (plan.md section 7.2). Google is a linked identity, not a
/// separate account (section 15.1): signing in with a Google identity
/// that's already linked authenticates directly; a first-time Google
/// identity is sent to the registration-completion screen instead.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _usernameOrEmailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _usernameOrEmailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final ok = await ref
        .read(loginControllerProvider.notifier)
        .submit(
          usernameOrEmail: _usernameOrEmailController.text,
          password: _passwordController.text,
        );
    if (ok && mounted) {
      context.go(AppRoutes.home);
    }
  }

  Future<void> _continueWithGoogle() async {
    final outcome = await ref
        .read(googleSignInControllerProvider.notifier)
        .signIn();
    if (!mounted || outcome == null) return;

    switch (outcome) {
      case GoogleSignInAuthenticated():
        context.go(AppRoutes.home);
      case GoogleSignInRegistrationRequired():
        ref.read(pendingGoogleRegistrationProvider.notifier).state = outcome;
        context.push(AppRoutes.registerGoogleCompletion);
      case GoogleSignInCancelledByUser():
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(loginControllerProvider);
    final googleState = ref.watch(googleSignInControllerProvider);
    final l10n = AppLocalizations.of(context);
    final canSubmit =
        !state.isSubmitting &&
        _usernameOrEmailController.text.isNotEmpty &&
        _passwordController.text.isNotEmpty;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.xl),
              Text(l10n.loginAction, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: AppSpacing.lg),
              if (state.error != null) ...[
                Text(
                  presentError(state.error!, l10n).message,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              TextField(
                controller: _usernameOrEmailController,
                onChanged: (_) => setState(() {}),
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: l10n.usernameOrEmailLabel,
                  errorText: state.fieldErrors['username_or_email'] == null
                      ? null
                      : localizeErrorCode(
                          l10n,
                          state.fieldErrors['username_or_email']!,
                        ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              PasswordField(
                controller: _passwordController,
                label: l10n.passwordLabel,
                errorText: state.fieldErrors['password'] == null
                    ? null
                    : localizeErrorCode(l10n, state.fieldErrors['password']!),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => canSubmit ? _submit() : null,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => context.push(AppRoutes.forgotPassword),
                  child: Text(l10n.forgotPasswordAction),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              FilledButton(
                onPressed: canSubmit ? _submit : null,
                child: state.isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.loginAction),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    child: Text(
                      l10n.orDividerLabel,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              if (googleState.error != null) ...[
                Text(
                  presentError(googleState.error!, l10n).message,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
              OutlinedButton.icon(
                onPressed: googleState.isSubmitting
                    ? null
                    : _continueWithGoogle,
                icon: googleState.isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.g_mobiledata),
                label: Text(l10n.continueWithGoogleAction),
              ),
              const SizedBox(height: AppSpacing.lg),
              Center(
                child: TextButton(
                  onPressed: () => context.push(AppRoutes.register),
                  child: Text(l10n.createAccountAction),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
