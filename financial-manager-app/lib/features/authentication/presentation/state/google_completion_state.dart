import 'package:flutter/material.dart';

class GoogleCompletionState {
  const GoogleCompletionState({
    this.username = '',
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

  final String username;
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

  GoogleCompletionState copyWith({
    String? username,
    String? password,
    String? confirmPassword,
    Color? avatarBackgroundColor,
    Color? avatarTextColor,
    String? initialBalanceInput,
    bool? acceptedTerms,
    bool? isSubmitting,
    String? generalError,
    Map<String, String>? fieldErrors,
  }) {
    return GoogleCompletionState(
      username: username ?? this.username,
      password: password ?? this.password,
      confirmPassword: confirmPassword ?? this.confirmPassword,
      avatarBackgroundColor:
          avatarBackgroundColor ?? this.avatarBackgroundColor,
      avatarTextColor: avatarTextColor ?? this.avatarTextColor,
      initialBalanceInput: initialBalanceInput ?? this.initialBalanceInput,
      currency: currency,
      timezone: timezone,
      locale: locale,
      acceptedTerms: acceptedTerms ?? this.acceptedTerms,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      generalError: generalError,
      fieldErrors: fieldErrors ?? this.fieldErrors,
    );
  }
}
