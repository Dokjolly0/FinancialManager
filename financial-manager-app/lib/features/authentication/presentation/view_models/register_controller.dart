import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/session/session_controller.dart';
import '../../../../core/errors/app_error.dart';
import '../../../../core/formatting/color_hex.dart';
import '../../../../core/formatting/money.dart';
import '../../data/providers.dart';
import '../../domain/repositories/auth_repository.dart';
import '../state/register_state.dart';

/// Index of the wizard's last step (Wallet). submit() is only ever called
/// from there, so error handling should target it directly rather than
/// trusting ambient state.step.
const _lastStep = 2;

class RegisterController extends AutoDisposeNotifier<RegisterState> {
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
      error: null,
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
      error: null,
    );
  }

  void setAcceptedTerms(bool value) =>
      state = state.copyWith(acceptedTerms: value);

  void setFieldErrors(Map<String, String> errors) {
    state = state.copyWith(fieldErrors: errors);
  }

  /// Client-side validation for step 0 (mirrors the backend's rules from
  /// plan.md section 4.4/15.5 so the user gets feedback before submitting).
  /// Field values are error codes (see [localizeErrorCode]), not display
  /// text, so they localize the same way as backend-sourced field errors.
  Map<String, String> validateAccountStep() {
    final s = state;
    final errors = <String, String>{};
    if (s.firstName.trim().isEmpty) {
      errors['first_name'] = 'REQUIRED_FIELD';
    }
    if (s.lastName.trim().isEmpty) errors['last_name'] = 'REQUIRED_FIELD';
    if (s.username.trim().length < 3) {
      errors['username'] = 'USERNAME_LENGTH_INVALID';
    }
    if (!s.email.contains('@')) errors['email'] = 'INVALID_EMAIL';
    if (s.password.length < 8) {
      errors['password'] = 'PASSWORD_TOO_SHORT';
    }
    if (s.password != s.confirmPassword) {
      errors['confirm_password'] = 'PASSWORDS_DO_NOT_MATCH';
    }
    return errors;
  }

  Future<bool> submit() async {
    final balanceMinor = Money.parseMinorUnits(state.initialBalanceInput);
    if (balanceMinor == null) {
      state = state.copyWith(
        fieldErrors: {'initial_balance_minor': 'INVALID_AMOUNT'},
      );
      return false;
    }
    if (!state.acceptedTerms) {
      state = state.copyWith(
        fieldErrors: {'accepted_terms': 'TERMS_NOT_ACCEPTED'},
      );
      return false;
    }

    state = state.copyWith(isSubmitting: true, error: null, fieldErrors: {});

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

      ref.read(sessionControllerProvider.notifier).signIn(user);
      state = state.copyWith(isSubmitting: false);
      return true;
    } on AppError catch (e) {
      final fieldErrors = e is DomainError ? e.fieldErrors : <String, String>{};
      // A field error on an account-step field means the user should go
      // back there to fix it (e.g. USERNAME_IN_USE surfaces on submit,
      // which only happens after step 2).
      final accountFields = {
        'username',
        'email',
        'password',
        'confirm_password',
      };
      final targetStep = fieldErrors.keys.any(accountFields.contains)
          ? 0
          : _lastStep;

      state = state.copyWith(
        isSubmitting: false,
        error: e,
        fieldErrors: fieldErrors,
        step: targetStep,
      );
      return false;
    }
  }
}

final registerControllerProvider =
    NotifierProvider.autoDispose<RegisterController, RegisterState>(
      RegisterController.new,
    );
