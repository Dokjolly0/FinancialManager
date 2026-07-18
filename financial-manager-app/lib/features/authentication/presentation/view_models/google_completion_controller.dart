import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/session/current_user_provider.dart';
import '../../../../app/session/pending_google_registration_provider.dart';
import '../../../../app/session/session_controller.dart';
import '../../../../core/errors/app_error.dart';
import '../../../../core/errors/error_presentation.dart';
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
      generalError: null,
    );
  }

  void setAvatarBackgroundColor(Color color) =>
      state = state.copyWith(avatarBackgroundColor: color);

  void setAcceptedTerms(bool value) =>
      state = state.copyWith(acceptedTerms: value);

  Future<bool> submit() async {
    final ticket = ref.read(pendingGoogleRegistrationProvider);
    if (ticket == null) {
      state = state.copyWith(
        generalError: 'Sessione di registrazione scaduta. Riprova con Google.',
      );
      return false;
    }

    final fieldErrors = <String, String>{};
    if (state.username.trim().length < 3) {
      fieldErrors['username'] = 'Deve avere almeno 3 caratteri.';
    }
    if (state.password.isNotEmpty) {
      if (state.password.length < 8) {
        fieldErrors['password'] = 'Deve avere almeno 8 caratteri.';
      }
      if (state.password != state.confirmPassword) {
        fieldErrors['confirm_password'] = 'Le password non coincidono.';
      }
    }
    final balanceMinor = Money.parseMinorUnits(state.initialBalanceInput);
    if (balanceMinor == null) {
      fieldErrors['initial_balance_minor'] = 'Importo non valido.';
    }
    if (!state.acceptedTerms) {
      fieldErrors['accepted_terms'] = 'Devi accettare i termini per procedere.';
    }
    if (fieldErrors.isNotEmpty) {
      state = state.copyWith(fieldErrors: fieldErrors);
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

      ref.read(currentUserProvider.notifier).state = user;
      ref.read(pendingGoogleRegistrationProvider.notifier).state = null;
      ref.read(sessionControllerProvider.notifier).signIn();
      state = state.copyWith(isSubmitting: false);
      return true;
    } on AppError catch (e) {
      final presentation = presentError(e);
      state = state.copyWith(
        isSubmitting: false,
        generalError: presentation.message,
        fieldErrors: presentation.fieldErrors,
      );
      return false;
    }
  }
}

final googleCompletionControllerProvider =
    NotifierProvider<GoogleCompletionController, GoogleCompletionState>(
      GoogleCompletionController.new,
    );
