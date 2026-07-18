import 'package:flutter/material.dart';

/// Accumulates the 3-step registration wizard's fields (plan.md section
/// 7.3) in one place, since the flow is a single logical submission split
/// across steps for UX reasons only.
class RegisterState {
  const RegisterState({
    this.step = 0,
    this.firstName = '',
    this.lastName = '',
    this.username = '',
    this.email = '',
    this.password = '',
    this.confirmPassword = '',
    this.avatarBackgroundColor = const Color(0xFF176B5B),
    this.avatarTextColor = const Color(0xFFFFFFFF),
    this.initialBalanceInput = '0',
    this.currency = 'EUR',
    this.timezone = 'Europe/Rome',
    this.locale = 'it-IT',
    this.acceptedTerms = false,
    this.isSubmitting = false,
    this.generalError,
    this.fieldErrors = const {},
  });

  final int step;
  final String firstName;
  final String lastName;
  final String username;
  final String email;
  final String password;
  final String confirmPassword;
  final Color avatarBackgroundColor;
  final Color avatarTextColor;
  final String initialBalanceInput;
  final String currency;
  final String timezone;
  final String locale;
  final bool acceptedTerms;
  final bool isSubmitting;
  final String? generalError;
  final Map<String, String> fieldErrors;

  RegisterState copyWith({
    int? step,
    String? firstName,
    String? lastName,
    String? username,
    String? email,
    String? password,
    String? confirmPassword,
    Color? avatarBackgroundColor,
    Color? avatarTextColor,
    String? initialBalanceInput,
    String? currency,
    String? timezone,
    String? locale,
    bool? acceptedTerms,
    bool? isSubmitting,
    String? generalError,
    Map<String, String>? fieldErrors,
  }) {
    return RegisterState(
      step: step ?? this.step,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      username: username ?? this.username,
      email: email ?? this.email,
      password: password ?? this.password,
      confirmPassword: confirmPassword ?? this.confirmPassword,
      avatarBackgroundColor:
          avatarBackgroundColor ?? this.avatarBackgroundColor,
      avatarTextColor: avatarTextColor ?? this.avatarTextColor,
      initialBalanceInput: initialBalanceInput ?? this.initialBalanceInput,
      currency: currency ?? this.currency,
      timezone: timezone ?? this.timezone,
      locale: locale ?? this.locale,
      acceptedTerms: acceptedTerms ?? this.acceptedTerms,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      generalError: generalError,
      fieldErrors: fieldErrors ?? this.fieldErrors,
    );
  }
}
