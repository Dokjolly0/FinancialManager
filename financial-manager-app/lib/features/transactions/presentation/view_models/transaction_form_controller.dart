import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_error.dart';
import '../../../../core/errors/error_presentation.dart';
import '../../../../core/formatting/money.dart';
import '../../../../core/state/ledger_revision_provider.dart';
import '../../../categories/domain/models/category.dart';
import '../../../templates/data/providers.dart';
import '../../../templates/domain/models/transaction_template.dart';
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
        categoryId: existing.categoryId,
        clearCategory: existing.categoryId == null,
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

  /// Setting the title manually breaks the link to a previously selected
  /// template the moment it stops matching that template's title (plan.md
  /// section 4.4: "Se l'utente modifica un campo dopo aver selezionato un
  /// modello, la transazione può divergere senza modificare automaticamente
  /// il modello").
  void setTitle(String value) {
    final diverged =
        state.selectedTemplateId != null &&
        normalizeTemplateTitle(value) != normalizeTemplateTitle(state.title);
    state = state.copyWith(
      title: value,
      fieldErrors: {},
      clearSelectedTemplate: diverged,
    );
  }

  void setDescription(String value) =>
      state = state.copyWith(description: value);

  void setOccurredAt(DateTime value) =>
      state = state.copyWith(occurredAt: value);

  void setCategory(Category? category) {
    state = state.copyWith(
      categoryId: category?.id,
      clearCategory: category == null,
    );
  }

  void setSaveAsTemplate(bool value) =>
      state = state.copyWith(saveAsTemplate: value);

  /// Applies an autocomplete suggestion (plan.md section 7.6: "Selezionando
  /// un suggerimento vengono precompilati i valori associati").
  void applyTemplate(TransactionTemplate template, Category? category) {
    state = state.copyWith(
      title: template.title,
      selectedTemplateId: template.id,
      description: template.defaultDescription ?? state.description,
      categoryId: category?.id,
      clearCategory: category == null,
    );
  }

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
    final title = state.title.trim();
    final categoryId = state.categoryId;
    final templateId = state.selectedTemplateId;

    try {
      if (state.isEditMode) {
        await ref
            .read(transactionRepositoryProvider)
            .updateStandard(
              arg!,
              UpdateTransactionParams(
                direction: direction,
                amountMinor: amountMinor!,
                title: title,
                description: description,
                categoryId: categoryId,
                templateId: templateId,
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
                title: title,
                description: description,
                categoryId: categoryId,
                templateId: templateId,
                occurredAt: occurredAt,
              ),
            );
      }
      state = state.copyWith(isSubmitting: false);
      ref.bumpLedgerRevision();
      if (state.saveAsTemplate) {
        await _persistTemplate(direction, title, categoryId, description);
      }
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

  /// Best-effort: the ledger mutation already succeeded, so a failure here
  /// (e.g. a race with another device creating the same-titled template)
  /// must never surface as an error to the user (plan.md section 4.4:
  /// "Dopo il salvataggio può essere offerta l'azione 'Aggiorna anche il
  /// modello'" — a convenience, not part of the financial operation).
  Future<void> _persistTemplate(
    TransactionDirection direction,
    String title,
    String? categoryId,
    String? description,
  ) async {
    try {
      final templates = ref.read(templateRepositoryProvider);
      if (state.selectedTemplateId != null) {
        await templates.update(
          state.selectedTemplateId!,
          title: title,
          defaultCategoryId: categoryId,
          defaultDescription: description,
        );
      } else {
        await templates.create(
          direction: direction,
          title: title,
          defaultCategoryId: categoryId,
          defaultDescription: description,
        );
      }
    } catch (_) {
      // Swallowed by design — see doc comment above.
    }
  }
}

final transactionFormControllerProvider = NotifierProvider.autoDispose
    .family<TransactionFormController, TransactionFormState, String?>(
      TransactionFormController.new,
    );
