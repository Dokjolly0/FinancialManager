import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_error.dart';
import '../../../../core/errors/error_presentation.dart';
import '../../../../core/formatting/money.dart';
import '../../../../core/state/ledger_revision_provider.dart';
import '../../data/providers.dart';
import '../../domain/models/transaction_direction.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../state/transaction_form_state.dart';

/// Backs both "new operation" and "edit operation" (plan.md section 7.6,
/// 7.11 — same form). Keyed by the transaction id being edited, or null
/// for a new one, via Riverpod's family so create/edit never share state.
class TransactionFormController
    extends AutoDisposeFamilyNotifier<TransactionFormState, String?> {
  @override
  TransactionFormState build(String? arg) {
    if (arg != null) {
      Future.microtask(() => _loadExisting(arg));
      return const TransactionFormState(isLoadingExisting: true);
    }
    return TransactionFormState(occurredAt: DateTime.now());
  }

  Future<void> _loadExisting(String id) async {
    try {
      final existing = await ref
          .read(transactionRepositoryProvider)
          .getTransaction(id);
      state = state.copyWith(
        isLoadingExisting: false,
        isCredit: existing.direction.isCredit,
        amountInput: (existing.amount.minorUnits / 100).toStringAsFixed(2),
        title: existing.title,
        description: existing.description ?? '',
        occurredAt: existing.occurredAt.toLocal(),
        expectedVersion: existing.version,
      );
    } on AppError catch (e) {
      state = state.copyWith(
        isLoadingExisting: false,
        generalError: presentError(e).message,
      );
    }
  }

  void setDirection(bool isCredit) =>
      state = state.copyWith(isCredit: isCredit);

  void setAmountInput(String value) => state = state.copyWith(
    amountInput: value,
    fieldErrors: {},
    generalError: null,
  );

  void setTitle(String value) =>
      state = state.copyWith(title: value, fieldErrors: {});

  void setDescription(String value) =>
      state = state.copyWith(description: value);

  void setOccurredAt(DateTime value) =>
      state = state.copyWith(occurredAt: value);

  Future<bool> submit() async {
    final amountMinor = Money.parseMinorUnits(state.amountInput);
    final fieldErrors = <String, String>{};
    if (amountMinor == null || amountMinor <= 0) {
      fieldErrors['amount_minor'] = 'Inserisci un importo maggiore di zero.';
    }
    if (state.title.trim().isEmpty) {
      fieldErrors['title'] = 'Campo obbligatorio.';
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

    final direction = state.isCredit
        ? TransactionDirection.credit
        : TransactionDirection.debit;
    final occurredAt = state.occurredAt ?? DateTime.now();
    final description = state.description.trim().isEmpty
        ? null
        : state.description.trim();

    try {
      if (state.isEditMode) {
        await ref
            .read(transactionRepositoryProvider)
            .updateStandard(
              arg!,
              UpdateTransactionParams(
                direction: direction,
                amountMinor: amountMinor!,
                title: state.title.trim(),
                description: description,
                occurredAt: occurredAt,
                expectedVersion: state.expectedVersion!,
              ),
            );
      } else {
        await ref
            .read(transactionRepositoryProvider)
            .createStandard(
              CreateTransactionParams(
                direction: direction,
                amountMinor: amountMinor!,
                currency: 'EUR',
                title: state.title.trim(),
                description: description,
                occurredAt: occurredAt,
              ),
            );
      }
      state = state.copyWith(isSubmitting: false);
      ref.bumpLedgerRevision();
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

final transactionFormControllerProvider = NotifierProvider.autoDispose
    .family<TransactionFormController, TransactionFormState, String?>(
      TransactionFormController.new,
    );
