import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/formatting/money.dart';
import '../../../../core/widgets/generated_avatar.dart';
import '../view_models/register_controller.dart';
import '../widgets/password_field.dart';

const _avatarColorChoices = [
  Color(0xFF176B5B),
  Color(0xFF175CD3),
  Color(0xFFB54708),
  Color(0xFFB42318),
  Color(0xFF6941C6),
];

/// Registration wizard (plan.md section 7.3): account, profile/avatar,
/// wallet — kept as three steps to avoid one very long form.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _balanceController = TextEditingController(text: '0');

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  void _syncAccountFields() {
    ref
        .read(registerControllerProvider.notifier)
        .updateAccountFields(
          firstName: _firstNameController.text,
          lastName: _lastNameController.text,
          username: _usernameController.text,
          email: _emailController.text,
          password: _passwordController.text,
          confirmPassword: _confirmPasswordController.text,
        );
  }

  Future<void> _submit() async {
    final ok = await ref.read(registerControllerProvider.notifier).submit();
    if (ok && mounted) {
      context.go(AppRoutes.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(registerControllerProvider);
    final controller = ref.read(registerControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Crea un account')),
      body: Stepper(
        currentStep: state.step,
        onStepContinue: () async {
          if (state.step == 0) {
            _syncAccountFields();
            final errors = controller.validateAccountStep();
            if (errors.isNotEmpty) {
              controller.setFieldErrors(errors);
              return;
            }
            controller.setStep(1);
          } else if (state.step == 1) {
            controller.setStep(2);
          } else {
            await _submit();
          }
        },
        onStepCancel: state.step == 0
            ? null
            : () => controller.setStep(state.step - 1),
        controlsBuilder: (context, details) {
          return Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: Row(
              children: [
                FilledButton(
                  onPressed: state.isSubmitting ? null : details.onStepContinue,
                  child: state.isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          state.step == 2 ? 'Conferma registrazione' : 'Avanti',
                        ),
                ),
                if (details.onStepCancel != null) ...[
                  const SizedBox(width: AppSpacing.sm),
                  TextButton(
                    onPressed: details.onStepCancel,
                    child: const Text('Indietro'),
                  ),
                ],
              ],
            ),
          );
        },
        steps: [
          Step(
            title: const Text('Account'),
            isActive: state.step >= 0,
            state: state.step > 0 ? StepState.complete : StepState.indexed,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _firstNameController,
                  decoration: InputDecoration(
                    labelText: 'Nome',
                    errorText: state.fieldErrors['first_name'],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _lastNameController,
                  decoration: InputDecoration(
                    labelText: 'Cognome',
                    errorText: state.fieldErrors['last_name'],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText: 'Username',
                    errorText: state.fieldErrors['username'],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    errorText: state.fieldErrors['email'],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
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
              ],
            ),
          ),
          Step(
            title: const Text('Profilo'),
            isActive: state.step >= 1,
            state: state.step > 1 ? StepState.complete : StepState.indexed,
            content: Column(
              children: [
                GeneratedAvatar(
                  firstName: _firstNameController.text,
                  lastName: _lastNameController.text,
                  backgroundColor: state.avatarBackgroundColor,
                  textColor: state.avatarTextColor,
                  radius: 40,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Colore sfondo',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Wrap(
                  spacing: AppSpacing.xs,
                  children: _avatarColorChoices.map((color) {
                    return _ColorSwatch(
                      color: color,
                      selected:
                          color.toARGB32() ==
                          state.avatarBackgroundColor.toARGB32(),
                      onTap: () => controller.updateProfileFields(
                        avatarBackgroundColor: color,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          Step(
            title: const Text('Portafoglio'),
            isActive: state.step >= 2,
            state: StepState.indexed,
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _balanceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  onChanged: (v) =>
                      controller.updateWalletFields(initialBalanceInput: v),
                  decoration: InputDecoration(
                    labelText: 'Saldo iniziale (EUR)',
                    errorText: state.fieldErrors['initial_balance_minor'],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                if (state.generalError != null)
                  Text(
                    state.generalError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
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
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Riepilogo: ${_firstNameController.text} ${_lastNameController.text}, '
                  '@${_usernameController.text}, saldo iniziale '
                  '${Money(minorUnits: Money.parseMinorUnits(state.initialBalanceInput) ?? 0, currency: 'EUR').format()}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: selected ? Border.all(color: Colors.black, width: 2) : null,
        ),
      ),
    );
  }
}
