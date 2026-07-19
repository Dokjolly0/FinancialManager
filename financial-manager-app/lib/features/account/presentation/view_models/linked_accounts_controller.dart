import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_error.dart';
import '../../../../core/errors/error_presentation.dart';
import '../../data/providers.dart';
import '../../domain/models/linked_identity.dart';

class LinkedAccountsState {
  const LinkedAccountsState({
    this.isLoading = false,
    this.identities = const [],
    this.error,
  });

  final bool isLoading;
  final List<LinkedIdentity> identities;
  final String? error;

  bool get isGoogleLinked => identities.any((i) => i.provider == 'google');

  LinkedAccountsState copyWith({
    bool? isLoading,
    List<LinkedIdentity>? identities,
    String? error,
    bool clearError = false,
  }) {
    return LinkedAccountsState(
      isLoading: isLoading ?? this.isLoading,
      identities: identities ?? this.identities,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Account collegati (plan.md section 7.13, 14.3).
class LinkedAccountsController extends Notifier<LinkedAccountsState> {
  @override
  LinkedAccountsState build() {
    Future.microtask(refresh);
    return const LinkedAccountsState();
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final identities = await ref.read(accountRepositoryProvider).listIdentities();
      state = state.copyWith(isLoading: false, identities: identities);
    } on AppError catch (e) {
      state = state.copyWith(isLoading: false, error: presentError(e).message);
    }
  }

  /// Returns null on success, or a message to show if it failed.
  Future<String?> linkGoogle(String currentPassword) async {
    try {
      await ref.read(accountRepositoryProvider).linkGoogle(currentPassword);
      await refresh();
      return null;
    } on AppError catch (e) {
      return presentError(e).message;
    }
  }

  Future<String?> unlinkGoogle() async {
    try {
      await ref.read(accountRepositoryProvider).unlinkGoogle();
      await refresh();
      return null;
    } on AppError catch (e) {
      return presentError(e).message;
    }
  }
}

final linkedAccountsControllerProvider =
    NotifierProvider<LinkedAccountsController, LinkedAccountsState>(
      LinkedAccountsController.new,
    );
