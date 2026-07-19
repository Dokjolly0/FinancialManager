import '../../../../core/errors/app_error.dart';
import '../../domain/models/account_session.dart';

class SecurityState {
  const SecurityState({
    this.isLoading = false,
    this.sessions = const [],
    this.error,
  });

  final bool isLoading;
  final List<AccountSession> sessions;
  final AppError? error;

  SecurityState copyWith({
    bool? isLoading,
    List<AccountSession>? sessions,
    AppError? error,
    bool clearError = false,
  }) {
    return SecurityState(
      isLoading: isLoading ?? this.isLoading,
      sessions: sessions ?? this.sessions,
      error: clearError ? null : (error ?? this.error),
    );
  }
}
