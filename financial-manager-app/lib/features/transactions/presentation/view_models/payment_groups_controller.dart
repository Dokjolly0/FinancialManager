import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_error.dart';
import '../../../../core/state/ledger_revision_provider.dart';
import '../../data/providers.dart';
import '../../domain/models/payment_group_summary.dart';

class PaymentGroupsState {
  const PaymentGroupsState({
    this.isLoading = true,
    this.groups = const [],
    this.error,
  });

  final bool isLoading;
  final List<PaymentGroupSummary> groups;
  final AppError? error;

  PaymentGroupsState copyWith({
    bool? isLoading,
    List<PaymentGroupSummary>? groups,
    AppError? error,
  }) {
    return PaymentGroupsState(
      isLoading: isLoading ?? this.isLoading,
      groups: groups ?? this.groups,
      error: error,
    );
  }
}

/// "Pagamenti collegati" list (plan.md linked-transactions feature): every
/// group of 2+ transactions the user has linked as installments of the
/// same logical expense. Refetches whenever any screen mutates the ledger
/// (same cross-feature invalidation as Cronologia/Home, via
/// ledgerRevisionProvider) — linking, unlinking, or deleting a member can
/// create, grow, shrink, or dissolve a group.
class PaymentGroupsController extends Notifier<PaymentGroupsState> {
  @override
  PaymentGroupsState build() {
    ref.listen(ledgerRevisionProvider, (_, _) => refresh());
    Future.microtask(refresh);
    return const PaymentGroupsState();
  }

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final groups = await ref
          .read(transactionRepositoryProvider)
          .listPaymentGroups();
      state = state.copyWith(isLoading: false, groups: groups);
    } on AppError catch (e) {
      state = state.copyWith(isLoading: false, error: e);
    }
  }
}

final paymentGroupsControllerProvider =
    NotifierProvider<PaymentGroupsController, PaymentGroupsState>(
      PaymentGroupsController.new,
    );
