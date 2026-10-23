import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/error_presentation.dart';
import '../../../../l10n/app_localizations.dart';
import '../view_models/reset_password_controller.dart';
import '../widgets/password_field.dart';

/// Opened by the link in the "forgot password" email, on the web dashboard
/// or in the app through Android App Links. Without a token, or once the
/// token is used or expired, it only offers to ask for a new link.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key, required this.token});

  final String? token;

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  String? _passwordError;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _submit() {
    final l10n = AppLocalizations.of(context);
    if (_passwordController.text.length < 8) {
      setState(() => _passwordError = l10n.errorCodePasswordTooShort);
      return;
    }
    if (_passwordController.text != _confirmController.text) {
      setState(() => _passwordError = l10n.errorCodePasswordsDoNotMatch);
      return;
    }
    setState(() => _passwordError = null);
    ref
        .read(resetPasswordControllerProvider.notifier)
        .submit(token: widget.token!, newPassword: _passwordController.text);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(resetPasswordControllerProvider);
    final l10n = AppLocalizations.of(context);
    final token = widget.token;

    final List<Widget> children;
    if (state.succeeded) {
      children = [
        Text(l10n.resetPasswordSuccessMessage),
        const SizedBox(height: AppSpacing.md),
        FilledButton(
          onPressed: () => context.go(AppRoutes.login),
          child: Text(l10n.loginAction),
        ),
      ];
    } else if (token == null || token.isEmpty || state.linkExpired) {
      children = [
        Text(l10n.errorCodeInvalidOrExpiredToken),
        const SizedBox(height: AppSpacing.md),
        FilledButton(
          onPressed: () => context.go(AppRoutes.forgotPassword),
          child: Text(l10n.requestNewLinkAction),
        ),
      ];
    } else {
      children = [
        Text(
          l10n.resetPasswordInstructionsMessage,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.md),
        PasswordField(
          controller: _passwordController,
          label: l10n.newPasswordLabel,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: AppSpacing.sm),
        PasswordField(
          controller: _confirmController,
          label: l10n.confirmPasswordLabel,
          errorText: _passwordError,
          onSubmitted: (_) => _submit(),
        ),
        if (state.error != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            presentError(state.error!, l10n).message,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        FilledButton(
          onPressed: state.isSubmitting ? null : _submit,
          child: state.isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.resetPasswordAction),
        ),
      ];
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.resetPasswordScreenTitle)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}
