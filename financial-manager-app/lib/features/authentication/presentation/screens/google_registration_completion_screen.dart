import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../app/session/pending_google_registration_provider.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/generated_avatar.dart';
import '../view_models/google_completion_controller.dart';
import '../widgets/password_field.dart';

const _avatarColorChoices = [
  Color(0xFF176B5B),
  Color(0xFF175CD3),
  Color(0xFFB54708),
  Color(0xFFB42318),
  Color(0xFF6941C6),
];

/// Completes registration after a Google sign-in that had no linked
/// account yet (plan.md section 7.4): name and (verified) email already
/// come from Google, so this only asks for what Google can't provide —
/// username, avatar, wallet, and an optional local password.
class GoogleRegistrationCompletionScreen extends ConsumerStatefulWidget {
  const GoogleRegistrationCompletionScreen({super.key});

  @override
  ConsumerState<GoogleRegistrationCompletionScreen> createState() =>
      _GoogleRegistrationCompletionScreenState();
}

class _GoogleRegistrationCompletionScreenState
    extends ConsumerState<GoogleRegistrationCompletionScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _balanceController = TextEditingController(text: '0');

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final controller = ref.read(googleCompletionControllerProvider.notifier);
    controller.updateFields(
      username: _usernameController.text,
      password: _passwordController.text,
      confirmPassword: _confirmPasswordController.text,
      initialBalanceInput: _balanceController.text,
    );
    final ok = await controller.submit();
    if (ok && mounted) {
      context.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ticket = ref.watch(pendingGoogleRegistrationProvider);
    final state = ref.watch(googleCompletionControllerProvider);
    final controller = ref.read(googleCompletionControllerProvider.notifier);

    if (ticket == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Completa la registrazione')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Sessione di registrazione scaduta.'),
                const SizedBox(height: AppSpacing.md),
                FilledButton(
                  onPressed: () => context.go(AppRoutes.login),
                  child: const Text('Torna al login'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Completa la registrazione')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Accesso confermato con Google come ${ticket.email}.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            Center(
              child: GeneratedAvatar(
                firstName: ticket.suggestedFirstName,
                lastName: ticket.suggestedLastName,
                backgroundColor: state.avatarBackgroundColor,
                textColor: state.avatarTextColor,
                radius: 40,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Center(
              child: Wrap(
                spacing: AppSpacing.xs,
                children: _avatarColorChoices.map((color) {
                  final selected =
                      color.toARGB32() ==
                      state.avatarBackgroundColor.toARGB32();
                  return InkWell(
                    onTap: () => controller.setAvatarBackgroundColor(color),
                    customBorder: const CircleBorder(),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: selected
                            ? Border.all(color: Colors.black, width: 2)
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _usernameController,
              decoration: InputDecoration(
                labelText: 'Username',
                errorText: state.fieldErrors['username'],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Password locale (facoltativa: senza, potrai accedere solo con Google)',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.xs),
            PasswordField(
              controller: _passwordController,
              label: 'Password',
              errorText: state.fieldErrors['password'],
            ),
            const SizedBox(height: AppSpacing.sm),
            PasswordField(
              controller: _confirmPasswordController,
              label: 'Conferma password',
              errorText: state.fieldErrors['confirm_password'],
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _balanceController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Saldo iniziale (EUR)',
                errorText: state.fieldErrors['initial_balance_minor'],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            CheckboxListTile(
              value: state.acceptedTerms,
              onChanged: (v) => controller.setAcceptedTerms(v ?? false),
              title: const Text(
                'Accetto i termini di servizio e la privacy policy',
              ),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            if (state.fieldErrors['accepted_terms'] != null)
              Text(
                state.fieldErrors['accepted_terms']!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            if (state.generalError != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                state.generalError!,
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
                  : const Text('Completa registrazione'),
            ),
          ],
        ),
      ),
    );
  }
}
