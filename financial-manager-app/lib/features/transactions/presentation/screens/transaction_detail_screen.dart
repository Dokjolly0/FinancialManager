import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/router.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/semantic_colors.dart';
import '../../../../core/errors/error_presentation.dart';
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
    final transaction = ref
        .watch(transactionDetailControllerProvider(transactionId))
        .transaction!;
    final semantic = context.semanticColors;
    final isCredit = transaction.direction.isCredit;
    final amountColor = isCredit ? semantic.credit : semantic.debit;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    final dateFormat = DateFormat('d MMMM y, HH:mm', 'it_IT');

    String? categoryName;
    if (transaction.categoryId != null) {
      final categories = ref.watch(categoriesProvider).value ?? const [];
      final matches = categories.where((c) => c.id == transaction.categoryId);
      categoryName = matches.isEmpty ? null : matches.first.name;
    }

    final wallets = ref.watch(walletsListProvider).value ?? const [];
    final walletName = _findWallet(wallets, transaction.walletId)?.name;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (transaction.mediaId != null) ...[
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                child: Image(
                  width: 160,
                  height: 160,
                  fit: BoxFit.cover,
                  image: NetworkImage(
                    ref
                        .read(mediaRepositoryProvider)
                        .contentUrl(transaction.mediaId!),
                    headers: ref.read(mediaRepositoryProvider).authHeaders(),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          Center(
            child: Text(
              '${isCredit ? '+' : '−'} ${transaction.amount.format()}',
              style: textTheme.displayLarge?.copyWith(color: amountColor),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _Row(label: l10n.titleFieldLabel, value: transaction.title),
          _Row(label: l10n.walletLabel, value: walletName ?? '—'),
          if (categoryName != null)
            _Row(label: l10n.categoryLabel, value: categoryName),
          _Row(
            label: l10n.sourceLabel,
            value: _kindLabel(l10n, transaction.kind),
          ),
          _Row(
            label: l10n.dateAndTimeLabel,
            value: dateFormat.format(transaction.occurredAt.toLocal()),
          ),
          if (transaction.description != null &&
              transaction.description!.isNotEmpty)
            _Row(label: l10n.descriptionLabel, value: transaction.description!),
          const Divider(height: AppSpacing.xl),
          _Row(
            label: l10n.createdLabel,
            value: dateFormat.format(transaction.createdAt.toLocal()),
          ),
          _Row(
            label: l10n.lastModifiedLabel,
            value: dateFormat.format(transaction.updatedAt.toLocal()),
          ),
        ],
      ),
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
