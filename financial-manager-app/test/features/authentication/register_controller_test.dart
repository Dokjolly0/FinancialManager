import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:financialmanager/features/authentication/presentation/view_models/register_controller.dart';

void main() {
  group('RegisterController.validateAccountStep', () {
    late ProviderContainer container;

    setUp(() => container = ProviderContainer());
    tearDown(() => container.dispose());

    test('reports no errors for valid fields', () {
      final controller = container.read(registerControllerProvider.notifier);
      controller.updateAccountFields(
        firstName: 'Mario',
        lastName: 'Rossi',
        username: 'mariorossi',
        email: 'mario@example.com',
        password: 'supersecret1',
        confirmPassword: 'supersecret1',
      );

      expect(controller.validateAccountStep(), isEmpty);
    });

    test('flags mismatched passwords', () {
      final controller = container.read(registerControllerProvider.notifier);
      controller.updateAccountFields(
        firstName: 'Mario',
        lastName: 'Rossi',
        username: 'mariorossi',
        email: 'mario@example.com',
        password: 'supersecret1',
        confirmPassword: 'different',
      );

      expect(controller.validateAccountStep(), contains('confirm_password'));
    });

    test('flags a short username and an invalid email', () {
      final controller = container.read(registerControllerProvider.notifier);
      controller.updateAccountFields(
        firstName: 'Mario',
        lastName: 'Rossi',
        username: 'ab',
        email: 'not-an-email',
        password: 'supersecret1',
        confirmPassword: 'supersecret1',
      );

      final errors = controller.validateAccountStep();
      expect(errors, contains('username'));
      expect(errors, contains('email'));
    });
  });
}
