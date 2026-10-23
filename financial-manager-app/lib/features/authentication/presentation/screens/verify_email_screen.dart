import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../app/session/session_controller.dart';
import '../../../../app/session/session_status.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/app_error.dart';
import '../../../../core/errors/error_presentation.dart';
import '../../../../l10n/app_localizations.dart';
import '../../data/providers.dart';
import '../view_models/verify_email_controller.dart';

/// Opened by the link in the verification email, signed in or not. Confirms
/// the address as soon as it opens; if the link is used or expired, a
/// signed-in user can ask for a new one.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  const VerifyEmailScreen({super.key, required this.token});

  final String? token;

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  bool _resending = false;
  bool _resent = false;

  Future<void> _resend() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _resending = true);
    try {
      await ref.read(authRepositoryProvider).resendVerification();
      if (mounted) setState(() => _resent = true);
    } on AppError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(presentError(e, l10n).message)));
      }
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final token = widget.token;
    final signedIn =
        ref.watch(sessionControllerProvider) == SessionStatus.authenticated;

    final goToApp = FilledButton(
      onPressed: () => context.go(signedIn ? AppRoutes.home : AppRoutes.login),
      child: Text(l10n.goToAppAction),
    );

    List<Widget> failed(String message) => [
      Text(message),
      const SizedBox(height: AppSpacing.md),
      if (signedIn && _resent)
        Text(l10n.verificationResentMessage)
      else if (signedIn)
        OutlinedButton(
          onPressed: _resending ? null : _resend,
          child: Text(l10n.resendVerificationAction),
        ),
      const SizedBox(height: AppSpacing.sm),
      goToApp,
    ];

    final List<Widget> children;
    if (token == null || token.isEmpty) {
      children = failed(l10n.errorCodeInvalidOrExpiredToken);
    } else {
      children = ref
          .watch(verifyEmailProvider(token))
          .when(
            loading: () => [
              Text(l10n.verifyEmailInProgressMessage),
              const SizedBox(height: AppSpacing.md),
              const Center(child: CircularProgressIndicator()),
            ],
            data: (_) => [
              Text(l10n.verifyEmailSuccessMessage),
              const SizedBox(height: AppSpacing.md),
              goToApp,
            ],
            error: (e, _) => failed(
              e is AppError
                  ? presentError(e, l10n).message
                  : l10n.errorCodeInvalidOrExpiredToken,
            ),
          );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l10n.verifyEmailScreenTitle)),
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
