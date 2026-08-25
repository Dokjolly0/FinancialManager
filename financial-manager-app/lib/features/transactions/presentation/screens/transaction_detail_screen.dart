import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/router.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/semantic_colors.dart';
import '../../../../core/errors/error_presentation.dart';
import '../../../../core/formatting/money.dart';
import '../../../../core/widgets/confirmation_sheet.dart';
import '../../../../core/widgets/inline_error.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../categories/data/providers.dart';
import '../../../media/data/providers.dart';
import '../../../wallets/data/providers.dart';
import '../../../wallets/domain/models/wallet.dart';
import '../../../wallets/presentation/widgets/voucher_expense_sheet.dart';
import '../../data/providers.dart';
import '../../domain/models/ledger_transaction.dart';
import '../../domain/models/transaction_direction.dart';
import '../view_models/transaction_detail_controller.dart';
import '../widgets/opening_balance_edit_sheet.dart';
import '../widgets/transfer_edit_sheet.dart';

Wallet? _findWallet(List<Wallet> wallets, String id) {
  final matches = wallets.where((w) => w.id == id);
  return matches.isEmpty ? null : matches.first;
}

/// A transaction's contribution to a payment group's combined total —
/// CREDIT adds, DEBIT subtracts, mirroring the backend's SignedDelta and
/// the day-total sums already shown in Cronologia.
Money _signedAmount(LedgerTransaction transaction) =>
    transaction.direction.isCredit ? transaction.amount : -transaction.amount;

/// Transaction detail (plan.md section 7.10): view, edit, delete. Edit and
/// delete are only offered for STANDARD transactions. OPENING_BALANCE and
/// TRANSFER also allow editing their amount/date, through a dedicated sheet
/// rather than the full form — BALANCE_ADJUSTMENT stays fully read-only.
class TransactionDetailScreen extends ConsumerWidget {
  const TransactionDetailScreen({super.key, required this.transactionId});

  final String transactionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(transactionDetailControllerProvider(transactionId));
    final controller = ref.read(
      transactionDetailControllerProvider(transactionId).notifier,
    );
    final l10n = AppLocalizations.of(context);

    final transactionWallet = state.transaction == null
        ? null
        : _findWallet(
            ref.watch(walletsListProvider).value ?? const [],
            state.transaction!.walletId,
          );
    final isVoucherExpense =
        state.transaction?.kind == TransactionKind.standard &&
        !(state.transaction?.systemGenerated ?? false) &&
        (state.transaction?.linkedTransactionId != null ||
            (transactionWallet?.isMealVoucher ?? false));

    Future<void> openVoucherExpenseEdit() async {
      final transaction = state.transaction!;
      final repo = ref.read(transactionRepositoryProvider);
      final wallets = await ref.read(walletsListProvider.future);

      LedgerTransaction voucherTx;
      Wallet? voucherWallet;
      LedgerTransaction? otherTx;
      Wallet? otherWallet;

      if (transactionWallet?.isMealVoucher ?? false) {
        voucherTx = transaction;
        voucherWallet = transactionWallet;
        if (transaction.linkedTransactionId != null) {
          otherTx = await repo.getTransaction(transaction.linkedTransactionId!);
          otherWallet = _findWallet(wallets, otherTx.walletId);
        }
      } else {
        voucherTx = await repo.getTransaction(transaction.linkedTransactionId!);
        voucherWallet = _findWallet(wallets, voucherTx.walletId);
        otherTx = transaction;
        otherWallet = transactionWallet;
      }

      if (!context.mounted) return;
      final changed = await VoucherExpenseSheet.show(
        context,
        editVoucherTransaction: voucherTx,
        editVoucherWallet: voucherWallet,
        editOtherTransaction: otherTx,
        editOtherWallet: otherWallet,
      );
      if (changed) controller.load();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.transactionDetailScreenTitle),
        actions: [
          if (isVoucherExpense) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: l10n.editTooltip,
              onPressed: openVoucherExpenseEdit,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: l10n.deleteTooltip,
              onPressed: state.isDeleting
                  ? null
                  : () async {
                      final confirmed = await ConfirmationSheet.show(
                        context,
                        title: l10n.deleteTransactionConfirmTitle,
                        message: l10n.deleteTransactionConfirmMessage,
                        confirmLabel: l10n.commonDelete,
                        isDestructive: true,
                      );
                      if (!confirmed) return;
                      final wallet = await controller.delete();
                      if (wallet != null && context.mounted) {
                        context.pop();
                      }
                    },
            ),
          ] else if (state.transaction?.isEditable ?? false) ...[
            IconButton(
              icon: const Icon(Icons.link),
              tooltip: l10n.addLinkedPaymentTooltip,
              onPressed: () async {
                final saved = await context.push<bool>(
                  AppRoutes.transactionsNewLinkedTo(transactionId),
                );
                if (saved == true) controller.load();
              },
            ),
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: l10n.editTooltip,
              onPressed: () async {
                final saved = await context.push<bool>(
                  AppRoutes.transactionEdit(transactionId),
                );
                if (saved == true) controller.load();
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: l10n.deleteTooltip,
              onPressed: state.isDeleting
                  ? null
                  : () async {
                      final confirmed = await ConfirmationSheet.show(
                        context,
                        title: l10n.deleteTransactionConfirmTitle,
                        message: l10n.deleteTransactionConfirmMessage,
                        confirmLabel: l10n.commonDelete,
                        isDestructive: true,
                      );
                      if (!confirmed) return;
                      final wallet = await controller.delete();
                      if (wallet != null && context.mounted) {
                        context.pop();
                      }
                    },
            ),
          ] else if (state.transaction?.isOpeningBalanceEditable ?? false) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: l10n.editTooltip,
              onPressed: () async {
                final changed = await OpeningBalanceEditSheet.show(
                  context,
                  transaction: state.transaction!,
                );
                if (changed) controller.load();
              },
            ),
          ] else if (state.transaction?.isTransferEditable ?? false) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: l10n.editTooltip,
              onPressed: () async {
                final changed = await TransferEditSheet.show(
                  context,
                  transaction: state.transaction!,
                );
                if (changed) controller.load();
              },
            ),
          ],
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.error != null && state.transaction == null
          ? InlineError(
              message: presentError(
                state.error!,
                AppLocalizations.of(context),
              ).message,
              onRetry: controller.load,
            )
          : _Detail(transactionId: transactionId),
    );
  }
}

class _Detail extends ConsumerWidget {
  const _Detail({required this.transactionId});

  final String transactionId;

  String _kindLabel(AppLocalizations l10n, TransactionKind kind) =>
      switch (kind) {
        TransactionKind.openingBalance => l10n.openingBalanceKindLabel,
        TransactionKind.balanceAdjustment => l10n.balanceAdjustmentKindLabel,
        TransactionKind.transfer => l10n.transferKindLabel,
        TransactionKind.standard => l10n.manualKindLabel,
        TransactionKind.unknown => '—',
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailState = ref.watch(
      transactionDetailControllerProvider(transactionId),
    );
    final transaction = detailState.transaction!;
    final l10n = AppLocalizations.of(context);
    final dateFormat = DateFormat('d MMMM y, HH:mm', 'it_IT');

    final categories = ref.watch(categoriesProvider).value ?? const [];
    String? categoryNameFor(String? categoryId) {
      if (categoryId == null) return null;
      final matches = categories.where((c) => c.id == categoryId);
      return matches.isEmpty ? null : matches.first.name;
    }

    final wallets = ref.watch(walletsListProvider).value ?? const [];
    final mediaRepo = ref.read(mediaRepositoryProvider);

    Widget summaryFor(LedgerTransaction t, {required bool isPrimary}) {
      return _TransactionSummary(
        transaction: t,
        isPrimary: isPrimary,
        walletName: _findWallet(wallets, t.walletId)?.name,
        categoryName: categoryNameFor(t.categoryId),
        kindLabel: _kindLabel(l10n, t.kind),
        imageUrl: t.mediaId == null ? null : mediaRepo.contentUrl(t.mediaId!),
        imageHeaders: mediaRepo.authHeaders(),
        dateFormat: dateFormat,
        l10n: l10n,
      );
    }

    // Every OTHER transaction sharing this one's payment group — the
    // primary transaction above is rendered separately so it isn't listed
    // twice (once at the top, once again as one of its own "linked"
    // siblings).
    final linkedMembers = detailState.groupMembers
        .where((member) => member.id != transaction.id)
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          summaryFor(transaction, isPrimary: true),
          if (linkedMembers.isNotEmpty) ...[
            const Divider(height: AppSpacing.xl),
            Text(
              l10n.linkedPaymentsSectionTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            for (final member in linkedMembers) ...[
              const Divider(height: AppSpacing.lg),
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.lg),
                child: InkWell(
                  onTap: () => context.push(
                    AppRoutes.transactionDetail(member.id),
                  ),
                  child: summaryFor(member, isPrimary: false),
                ),
              ),
            ],
            const Divider(height: AppSpacing.lg),
            _Row(
              label: l10n.linkedPaymentsTotalLabel,
              value: detailState.groupMembers
                  .fold<Money>(
                    Money.zeroEur,
                    (total, member) => total + _signedAmount(member),
                  )
                  .format(),
            ),
          ],
        ],
      ),
    );
  }
}

/// One transaction's full field set — image, amount, and every [_Row] —
/// used both for the primary transaction at the top of the screen and,
/// smaller, for each of its linked siblings (plan.md linked-transactions
/// feature: every linked payment shows the same data as if it were the
/// one being viewed directly, not just a compact summary line).
class _TransactionSummary extends StatelessWidget {
  const _TransactionSummary({
    required this.transaction,
    required this.isPrimary,
    required this.walletName,
    required this.categoryName,
    required this.kindLabel,
    required this.imageUrl,
    required this.imageHeaders,
    required this.dateFormat,
    required this.l10n,
  });

  final LedgerTransaction transaction;
  final bool isPrimary;
  final String? walletName;
  final String? categoryName;
  final String kindLabel;
  final String? imageUrl;
  final Map<String, String> imageHeaders;
  final DateFormat dateFormat;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semanticColors;
    final isCredit = transaction.direction.isCredit;
    final amountColor = isCredit ? semantic.credit : semantic.debit;
    final textTheme = Theme.of(context).textTheme;
    final imageSize = isPrimary ? 160.0 : 96.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (imageUrl != null) ...[
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
              child: Image(
                width: imageSize,
                height: imageSize,
                fit: BoxFit.cover,
                image: NetworkImage(imageUrl!, headers: imageHeaders),
              ),
            ),
          ),
          SizedBox(height: isPrimary ? AppSpacing.md : AppSpacing.sm),
        ],
        Center(
          child: Text(
            '${isCredit ? '+' : '−'} ${transaction.amount.format()}',
            style: (isPrimary ? textTheme.displayLarge : textTheme.headlineSmall)
                ?.copyWith(color: amountColor),
          ),
        ),
        SizedBox(height: isPrimary ? AppSpacing.lg : AppSpacing.sm),
        _Row(label: l10n.titleFieldLabel, value: transaction.title),
        _Row(label: l10n.walletLabel, value: walletName ?? '—'),
        if (categoryName != null)
          _Row(label: l10n.categoryLabel, value: categoryName!),
        _Row(label: l10n.sourceLabel, value: kindLabel),
        _Row(
          label: l10n.dateAndTimeLabel,
          value: dateFormat.format(transaction.occurredAt.toLocal()),
        ),
        if (transaction.description != null &&
            transaction.description!.isNotEmpty)
          _Row(label: l10n.descriptionLabel, value: transaction.description!),
        _Row(
          label: l10n.createdLabel,
          value: dateFormat.format(transaction.createdAt.toLocal()),
        ),
        _Row(
          label: l10n.lastModifiedLabel,
          value: dateFormat.format(transaction.updatedAt.toLocal()),
        ),
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value, style: textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
