import 'package:flutter_test/flutter_test.dart';

import 'package:financialmanager/core/errors/app_error.dart';
import 'package:financialmanager/core/errors/error_presentation.dart';
import 'package:financialmanager/l10n/app_localizations_it.dart';

void main() {
  final l10n = AppLocalizationsIt();

  test('localizes field errors sent as codes', () {
    const error = DomainError(
      code: 'USERNAME_IN_USE',
      message: 'Username already in use.',
      fieldErrors: {'username': 'USERNAME_IN_USE'},
    );

    final presented = presentError(error, l10n);

    expect(presented.message, l10n.errorCodeUsernameInUse);
    expect(presented.fieldErrors['username'], l10n.errorCodeUsernameInUse);
  });

  test('an unknown field error falls back to the error message', () {
    // What the backend sent before it used codes for conflicts.
    const error = DomainError(
      code: 'EMAIL_IN_USE',
      message: 'Email already registered.',
      fieldErrors: {'email': 'Email already registered.'},
    );

    final presented = presentError(error, l10n);

    expect(presented.fieldErrors['email'], l10n.errorCodeEmailInUse);
    expect(presented.fieldErrors['email'], isNot(l10n.errorCodeUnknownError));
  });

  test('localizeFieldError: known codes as is, unknown ones via the error', () {
    const conflict = DomainError(
      code: 'USERNAME_IN_USE',
      message: 'Username already in use.',
    );

    expect(
      localizeFieldError(l10n, 'PASSWORD_TOO_SHORT', null),
      l10n.errorCodePasswordTooShort,
    );
    expect(
      localizeFieldError(l10n, 'Username already in use.', conflict),
      l10n.errorCodeUsernameInUse,
    );
    expect(
      localizeFieldError(l10n, 'something new', null),
      l10n.errorCodeUnknownError,
    );
  });
}
