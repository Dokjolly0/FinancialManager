import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/session/pending_google_registration_provider.dart';
import '../../../../app/session/session_controller.dart';
import '../../../../core/errors/app_error.dart';
import '../../../../core/formatting/color_hex.dart';
import '../../../../core/formatting/money.dart';
import '../../data/providers.dart';
import '../../domain/repositories/auth_repository.dart';
import '../state/google_completion_state.dart';

class GoogleCompletionController extends Notifier<GoogleCompletionState> {
  @override
  GoogleCompletionState build() => const GoogleCompletionState();

  void updateFields({
    String? username,
    String? password,
    String? confirmPassword,
    String? initialBalanceInput,
  }) {
    state = state.copyWith(
      username: username,
      password: password,
      confirmPassword: confirmPassword,
      initialBalanceInput: initialBalanceInput,
      fieldErrors: {},
      error: null,
    );
  }

  void setAvatarBackgroundColor(Color color) =>
      state = state.copyWith(avatarBackgroundColor: color);

  void setAcceptedTerms(bool value) =>
      state = state.copyWith(acceptedTerms: value);

  Future<bool> submit() async {
    final ticket = ref.read(pendingGoogleRegistrationProvider);
    if (ticket == null) {
      // The screen watches the same provider and shows its own dedicated
      // "session expired" view whenever the ticket is null, so this state
      // is defensive only — it's never actually rendered from here.
      return false;
    }

    final fieldErrors = <String, String>{};
    if (state.username.trim().length < 3) {
      fieldErrors['username'] = 'USERNAME_LENGTH_INVALID';
    }
    if (state.password.isNotEmpty) {
      if (state.password.length < 8) {
        fieldErrors['password'] = 'PASSWORD_TOO_SHORT';
      }
      if (state.password != state.confirmPassword) {
        fieldErrors['confirm_password'] = 'PASSWORDS_DO_NOT_MATCH';
      }
    }
    final balanceMinor = Money.parseMinorUnits(state.initialBalanceInput);
    if (balanceMinor == null) {
      fieldErrors['initial_balance_minor'] = 'INVALID_AMOUNT';
    }
    if (!state.acceptedTerms) {
      fieldErrors['accepted_terms'] = 'TERMS_NOT_ACCEPTED';
    }
    if (fieldErrors.isNotEmpty) {
      state = state.copyWith(fieldErrors: fieldErrors);
      return false;
    }

    state = state.copyWith(isSubmitting: true, error: null, fieldErrors: {});

    try {
      final user = await ref
          .read(authRepositoryProvider)
          .completeGoogleRegistration(
            GoogleCompletionParams(
              ticket: ticket.ticket,
              username: state.username.trim(),
              password: state.password,
              confirmPassword: state.confirmPassword,
              avatarBackgroundColor: colorToHex(state.avatarBackgroundColor),
              avatarTextColor: colorToHex(state.avatarTextColor),
              initialBalanceMinor: balanceMinor!,
              currency: state.currency,
              timezone: state.timezone,
              locale: state.locale,
              acceptedTerms: state.acceptedTerms,
            ),
          );

      ref.read(pendingGoogleRegistrationProvider.notifier).state = null;
      ref.read(sessionControllerProvider.notifier).signIn(user);
      state = state.copyWith(isSubmitting: false);
      return true;
    } on AppError catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        error: e,
        fieldErrors: e is DomainError ? e.fieldErrors : const {},
      );
      return false;
    }
  }
}

final googleCompletionControllerProvider =
    NotifierProvider<GoogleCompletionController, GoogleCompletionState>(
      GoogleCompletionController.new,
    );
