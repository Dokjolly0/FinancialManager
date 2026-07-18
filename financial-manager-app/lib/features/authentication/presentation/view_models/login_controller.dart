import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/session/current_user_provider.dart';
import '../../../../app/session/session_controller.dart';
import '../../../../core/errors/app_error.dart';
import '../../../../core/errors/error_presentation.dart';
import '../../data/providers.dart';
import '../state/login_state.dart';

class LoginController extends Notifier<LoginState> {
  @override
  LoginState build() => const LoginState();

  Future<bool> submit({
    required String usernameOrEmail,
    required String password,
  }) async {
    state = state.copyWith(
      isSubmitting: true,
      generalError: null,
      fieldErrors: {},
    );

    try {
      final user = await ref
          .read(authRepositoryProvider)
          .login(usernameOrEmail: usernameOrEmail, password: password);

      ref.read(currentUserProvider.notifier).state = user;
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

final loginControllerProvider = NotifierProvider<LoginController, LoginState>(
  LoginController.new,
);
