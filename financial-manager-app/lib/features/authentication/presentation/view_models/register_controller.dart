import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/session/current_user_provider.dart';
import '../../../../app/session/session_controller.dart';
import '../../../../core/errors/app_error.dart';
import '../../../../core/errors/error_presentation.dart';
import '../../../../core/formatting/color_hex.dart';
import '../../../../core/formatting/money.dart';
import '../../data/providers.dart';
import '../../domain/repositories/auth_repository.dart';
import '../state/register_state.dart';

class RegisterController extends Notifier<RegisterState> {
  @override
  RegisterState build() => const RegisterState();

  void setStep(int step) => state = state.copyWith(step: step);

  void updateAccountFields({
    String? firstName,
    String? lastName,
    String? username,
    String? email,
    String? password,
    String? confirmPassword,
  }) {
    state = state.copyWith(
      firstName: firstName,
      lastName: lastName,
      username: username,
      email: email,
      password: password,
      confirmPassword: confirmPassword,
      fieldErrors: {},
      generalError: null,
    );
  }

  void updateProfileFields({
    Color? avatarBackgroundColor,
    Color? avatarTextColor,
  }) {
    state = state.copyWith(
      avatarBackgroundColor: avatarBackgroundColor,
      avatarTextColor: avatarTextColor,
    );
  }

  void updateWalletFields({String? initialBalanceInput, String? timezone}) {
    state = state.copyWith(
      initialBalanceInput: initialBalanceInput,
      timezone: timezone,
      fieldErrors: {},
      generalError: null,
    );
  }

  void setAcceptedTerms(bool value) =>
      state = state.copyWith(acceptedTerms: value);

  void setFieldErrors(Map<String, String> errors) {
    state = state.copyWith(fieldErrors: errors);
  }

  /// Client-side validation for step 0 (mirrors the backend's rules from
  /// plan.md section 4.4/15.5 so the user gets feedback before submitting).
  Map<String, String> validateAccountStep() {
    final s = state;
    final errors = <String, String>{};
    if (s.firstName.trim().isEmpty) {
      errors['first_name'] = 'Campo obbligatorio.';
    }
    if (s.lastName.trim().isEmpty) errors['last_name'] = 'Campo obbligatorio.';
    if (s.username.trim().length < 3) {
      errors['username'] = 'Deve avere almeno 3 caratteri.';
    }
    if (!s.email.contains('@')) errors['email'] = 'Email non valida.';
    if (s.password.length < 8) {
      errors['password'] = 'Deve avere almeno 8 caratteri.';
    }
    if (s.password != s.confirmPassword) {
      errors['confirm_password'] = 'Le password non coincidono.';
    }
    return errors;
  }

  Future<bool> submit() async {
    final balanceMinor = Money.parseMinorUnits(state.initialBalanceInput);
    if (balanceMinor == null) {
      state = state.copyWith(
        fieldErrors: {'initial_balance_minor': 'Importo non valido.'},
      );
      return false;
    }
    if (!state.acceptedTerms) {
      state = state.copyWith(
        fieldErrors: {'accepted_terms': 'Devi accettare i termini.'},
      );
      return false;
    }

    state = state.copyWith(
      isSubmitting: true,
      generalError: null,
      fieldErrors: {},
    );

    try {
      final user = await ref
          .read(authRepositoryProvider)
          .register(
            RegisterParams(
              firstName: state.firstName.trim(),
              lastName: state.lastName.trim(),
              username: state.username.trim(),
              email: state.email.trim(),
              password: state.password,
              confirmPassword: state.confirmPassword,
              avatarBackgroundColor: colorToHex(state.avatarBackgroundColor),
              avatarTextColor: colorToHex(state.avatarTextColor),
              initialBalanceMinor: balanceMinor,
              currency: state.currency,
              timezone: state.timezone,
              locale: state.locale,
              acceptedTerms: state.acceptedTerms,
            ),
          );

      ref.read(currentUserProvider.notifier).state = user;
      ref.read(sessionControllerProvider.notifier).signIn();
      state = state.copyWith(isSubmitting: false);
      return true;
    } on AppError catch (e) {
      final presentation = presentError(e);
      // A field error on an account-step field means the user should go
      // back there to fix it (e.g. USERNAME_IN_USE surfaces on submit,
      // which only happens after step 2).
      final accountFields = {
        'username',
        'email',
        'password',
        'confirm_password',
      };
      final targetStep =
          presentation.fieldErrors.keys.any(accountFields.contains)
          ? 0
          : state.step;

      state = state.copyWith(
        isSubmitting: false,
        generalError: presentation.message,
        fieldErrors: presentation.fieldErrors,
        step: targetStep,
      );
      return false;
    }
  }
}

final registerControllerProvider =
    NotifierProvider<RegisterController, RegisterState>(RegisterController.new);
