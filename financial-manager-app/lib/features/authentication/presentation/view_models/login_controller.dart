import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/session/session_controller.dart';
import '../../../../core/errors/app_error.dart';
import '../../data/providers.dart';
import '../state/login_state.dart';

class LoginController extends Notifier<LoginState> {
  @override
  LoginState build() => const LoginState();

  Future<bool> submit({
    required String usernameOrEmail,
    required String password,
  }) async {
    state = state.copyWith(isSubmitting: true, error: null, fieldErrors: {});

    try {
      final user = await ref
          .read(authRepositoryProvider)
          .login(usernameOrEmail: usernameOrEmail, password: password);

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

final loginControllerProvider = NotifierProvider<LoginController, LoginState>(
  LoginController.new,
);
