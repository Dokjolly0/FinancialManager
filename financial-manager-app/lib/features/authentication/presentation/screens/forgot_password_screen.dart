import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/error_presentation.dart';
import '../../../../l10n/app_localizations.dart';
import '../view_models/forgot_password_controller.dart';

/// Password recovery request (plan.md section 7.13/14.1). Always shows the
/// same success message regardless of whether the email exists, to avoid
/// account enumeration (mirrors the backend's behavior).
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(forgotPasswordControllerProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.forgotPasswordScreenTitle)),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (state.succeeded)
              Text(l10n.forgotPasswordSuccessMessage)
            else ...[
              Text(
                l10n.forgotPasswordInstructionsMessage,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(labelText: l10n.emailLabel),
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
                onPressed: state.isSubmitting
                    ? null
                    : () => ref
                          .read(forgotPasswordControllerProvider.notifier)
                          .submit(_emailController.text),
                child: state.isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.sendAction),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
