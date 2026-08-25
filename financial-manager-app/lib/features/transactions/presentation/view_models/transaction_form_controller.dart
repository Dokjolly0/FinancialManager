import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_error.dart';
import '../../../../core/formatting/money.dart';
import '../../../../core/state/ledger_revision_provider.dart';
import '../../../categories/domain/models/category.dart';
import '../../../templates/data/providers.dart';
import '../../../templates/domain/models/transaction_template.dart';
import '../../../wallets/data/providers.dart';
import '../../data/providers.dart';
import '../../domain/models/transaction_direction.dart';
import '../../domain/repositories/transaction_repository.dart';
import '../state/transaction_form_state.dart';

/// Which existing transaction (if any) this form is bound to: an id being
/// edited, or an id this new transaction will be linked to on submit
/// ("pagamenti collegati") — never both. A record gives Riverpod's family
/// the structural equality it needs for caching without a hand-rolled
/// class; there's no equatable/freezed dependency in this project to
/// otherwise model it on.
typedef TransactionFormArg = ({
  String? editTransactionId,
  String? linkToTransactionId,
});

/// Backs both "new operation" and "edit operation" (plan.md section 7.6,
/// 7.11 — same form), plus "add a payment linked to an existing
/// transaction". Keyed by [TransactionFormArg] via Riverpod's family so
/// create/edit/linked-create never share state.
class TransactionFormController extends Notifier<TransactionFormState> {
  TransactionFormController(this.arg);

  final TransactionFormArg arg;

  @override
  TransactionFormState build() {
    // Defaults the wallet to the user's first one once the list resolves,
    // but only if nothing has been picked yet (either by this listener
    // firing again, or a manual pick / loaded-existing value already
    // applied) — mirrors HomeController's "apply once" guard for the same
    // reason: a later unrelated refetch must never clobber a real choice.
    // This also protects _loadExisting/_loadLinkSource's own async wallet
    // prefill below, since both set state.walletId before this listener
    // typically fires.
    ref.listen(walletsListProvider, (_, next) {
      final wallets = next.value;
      if (wallets == null || wallets.isEmpty || state.walletId != null) {
        return;
      }
      state = state.copyWith(walletId: wallets.first.id);
    });

    final editTransactionId = arg.editTransactionId;
    if (editTransactionId != null) {
      Future.microtask(() => _loadExisting(editTransactionId));
      return const TransactionFormState(isLoadingExisting: true);
    }
    final linkToTransactionId = arg.linkToTransactionId;
    if (linkToTransactionId != null) {
      Future.microtask(() => _loadLinkSource(linkToTransactionId));
      return const TransactionFormState(isLoadingExisting: true);
    }
    final wallets = ref.read(walletsListProvider).value;
    return TransactionFormState(
      occurredAt: DateTime.now(),
      walletId: (wallets != null && wallets.isNotEmpty)
          ? wallets.first.id
          : null,
    );
  }

  Future<void> _loadExisting(String id) async {
    try {
      final existing = await ref
          .read(transactionRepositoryProvider)
          .getTransaction(id);
      state = state.copyWith(
        isLoadingExisting: false,
        isCredit: existing.direction.isCredit,
        walletId: existing.walletId,
        amountInput: (existing.amount.minorUnits / 100).toStringAsFixed(2),
        title: existing.title,
        description: existing.description ?? '',
        categoryId: existing.categoryId,
        clearCategory: existing.categoryId == null,
        mediaId: existing.mediaId,
        clearMedia: existing.mediaId == null,
        occurredAt: existing.occurredAt.toLocal(),
        expectedVersion: existing.version,
      );
    } on AppError catch (e) {
      state = state.copyWith(isLoadingExisting: false, error: e);
    }
  }

  /// Prefills "aggiungi pagamento collegato" from the source transaction it
  /// will be linked to on submit — wallet/category/title/direction/image.
  /// The amount is left blank and the date defaults to now, since a saldo
  /// is rarely the same amount or day as its acconto; no version is set,
  /// since this creates a new transaction rather than editing [sourceId].
  Future<void> _loadLinkSource(String sourceId) async {
    try {
      final source = await ref
          .read(transactionRepositoryProvider)
          .getTransaction(sourceId);
      state = state.copyWith(
        isLoadingExisting: false,
        isCredit: source.direction.isCredit,
        walletId: source.walletId,
        title: source.title,
        categoryId: source.categoryId,
        clearCategory: source.categoryId == null,
        mediaId: source.mediaId,
        clearMedia: source.mediaId == null,
        occurredAt: DateTime.now(),
        linkToTransactionId: sourceId,
      );
    } on AppError catch (e) {
      state = state.copyWith(isLoadingExisting: false, error: e);
    }
  }

  void setDirection(bool isCredit) =>
      state = state.copyWith(isCredit: isCredit);

  void setWallet(String walletId) => state = state.copyWith(walletId: walletId);

  void setAmountInput(String value) =>
      state = state.copyWith(amountInput: value, fieldErrors: {}, error: null);

  /// Setting the title manually breaks the link to a previously selected
  /// template the moment it stops matching that template's title (plan.md
  /// section 4.4: "If the user edits a field after selecting a template,
  /// the transaction can diverge without automatically updating the
  /// template").
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

  void setMedia(String? mediaId) {
    state = state.copyWith(mediaId: mediaId, clearMedia: mediaId == null);
  }

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
      fieldErrors['amount_minor'] = 'AMOUNT_NOT_POSITIVE';
    }
    if (state.title.trim().isEmpty) {
      fieldErrors['title'] = 'REQUIRED_FIELD';
    }
    if (state.walletId == null) {
      fieldErrors['wallet_id'] = 'REQUIRED_FIELD';
    }
    if (fieldErrors.isNotEmpty) {
      state = state.copyWith(fieldErrors: fieldErrors);
      return false;
    }

    state = state.copyWith(isSubmitting: true, error: null, fieldErrors: {});

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
    final mediaId = state.mediaId;
    final walletId = state.walletId!;

    try {
      if (state.isEditMode) {
        await ref
            .read(transactionRepositoryProvider)
            .updateStandard(
              arg.editTransactionId!,
              UpdateTransactionParams(
                walletId: walletId,
                direction: direction,
                amountMinor: amountMinor!,
                title: title,
                description: description,
                categoryId: categoryId,
                templateId: templateId,
                mediaId: mediaId,
                occurredAt: occurredAt,
                expectedVersion: state.expectedVersion!,
              ),
            );
      } else {
        await ref
            .read(transactionRepositoryProvider)
            .createStandard(
              CreateTransactionParams(
                walletId: walletId,
                direction: direction,
                amountMinor: amountMinor!,
                currency: 'EUR',
                title: title,
                description: description,
                categoryId: categoryId,
                templateId: templateId,
                mediaId: mediaId,
                occurredAt: occurredAt,
                linkToTransactionId: state.linkToTransactionId,
              ),
            );
      }
      state = state.copyWith(isSubmitting: false);
      ref.bumpLedgerRevision();
      ref.invalidate(walletsListProvider);
      if (state.saveAsTemplate) {
        await _persistTemplate(direction, title, categoryId, description);
      }
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

  /// Best-effort: the ledger mutation already succeeded, so a failure here
  /// (e.g. a race with another device creating the same-titled template)
  /// must never surface as an error to the user (plan.md section 4.4:
  /// "After saving, the action 'Also update the template' may be offered"
  /// — a convenience, not part of the financial operation).
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
    .family<TransactionFormController, TransactionFormState, TransactionFormArg>(
      TransactionFormController.new,
    );
