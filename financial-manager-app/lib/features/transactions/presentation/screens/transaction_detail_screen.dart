import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../app/router.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/semantic_colors.dart';
import '../../../../core/widgets/confirmation_sheet.dart';
import '../../../../core/widgets/inline_error.dart';
import '../../../categories/data/providers.dart';
import '../../../media/data/providers.dart';
import '../../domain/models/transaction_direction.dart';
import '../view_models/transaction_detail_controller.dart';

/// Transaction detail (plan.md section 7.10): view, edit, delete. Edit and
/// delete are only offered for STANDARD transactions — OPENING_BALANCE and
/// BALANCE_ADJUSTMENT are shown read-only with a dedicated label.
class TransactionDetailScreen extends ConsumerWidget {
  const TransactionDetailScreen({super.key, required this.transactionId});

  final String transactionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(transactionDetailControllerProvider(transactionId));
    final controller = ref.read(
      transactionDetailControllerProvider(transactionId).notifier,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dettaglio operazione'),
        actions: [
          if (state.transaction?.isEditable ?? false) ...[
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Modifica',
              onPressed: () async {
                final saved = await context.push<bool>(
                  AppRoutes.transactionEdit(transactionId),
                );
                if (saved == true) controller.load();
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Elimina',
              onPressed: state.isDeleting
                  ? null
                  : () async {
                      final confirmed = await ConfirmationSheet.show(
                        context,
                        title: 'Eliminare questa operazione?',
                        message: 'Il saldo verrà aggiornato di conseguenza.',
                        confirmLabel: 'Elimina',
                        isDestructive: true,
                      );
                      if (!confirmed) return;
                      final wallet = await controller.delete();
                      if (wallet != null && context.mounted) {
                        context.pop();
                      }
                    },
            ),
          ],
        ],
      ),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.error != null && state.transaction == null
          ? InlineError(message: state.error!, onRetry: controller.load)
          : _Detail(transactionId: transactionId),
    );
  }
}

class _Detail extends ConsumerWidget {
  const _Detail({required this.transactionId});

  final String transactionId;

  String _kindLabel(TransactionKind kind) => switch (kind) {
    TransactionKind.openingBalance => 'Saldo iniziale',
    TransactionKind.balanceAdjustment => 'Rettifica saldo',
    TransactionKind.standard => 'Manuale',
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
    final dateFormat = DateFormat('d MMMM y, HH:mm', 'it_IT');

    String? categoryName;
    if (transaction.categoryId != null) {
      final categories = ref.watch(categoriesProvider).valueOrNull ?? const [];
      final matches = categories.where((c) => c.id == transaction.categoryId);
      categoryName = matches.isEmpty ? null : matches.first.name;
    }

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
          _Row(label: 'Titolo', value: transaction.title),
          if (categoryName != null)
            _Row(label: 'Categoria', value: categoryName),
          _Row(label: 'Origine', value: _kindLabel(transaction.kind)),
          _Row(
            label: 'Data e ora',
            value: dateFormat.format(transaction.occurredAt.toLocal()),
          ),
          if (transaction.description != null &&
              transaction.description!.isNotEmpty)
            _Row(label: 'Descrizione', value: transaction.description!),
          const Divider(height: AppSpacing.xl),
          _Row(
            label: 'Creata il',
            value: dateFormat.format(transaction.createdAt.toLocal()),
          ),
          _Row(
            label: 'Ultima modifica',
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
