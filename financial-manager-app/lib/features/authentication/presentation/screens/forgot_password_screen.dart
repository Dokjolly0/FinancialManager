import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
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

    return Scaffold(
      appBar: AppBar(title: const Text('Password dimenticata')),
      body: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (state.succeeded)
              const Text(
                'Se l\'indirizzo è registrato, riceverai a breve un\'email con le '
                'istruzioni per reimpostare la password.',
              )
            else ...[
              Text(
                'Inserisci la tua email: ti invieremo le istruzioni per '
                'reimpostare la password.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              if (state.error != null) ...[
                const SizedBox(height: AppSpacing.xs),
                Text(
                  state.error!,
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
                    : const Text('Invia'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
