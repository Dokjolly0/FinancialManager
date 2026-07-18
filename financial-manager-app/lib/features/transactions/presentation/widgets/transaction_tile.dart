import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/semantic_colors.dart';
import '../../domain/models/ledger_transaction.dart';
import '../../domain/models/transaction_direction.dart';

/// A row in the recent-operations / history lists (plan.md section 6.6,
/// 7.5, 7.9). Direction is conveyed by icon, sign, and position — not
/// color alone (plan.md section 6.7).
class TransactionTile extends StatelessWidget {
  const TransactionTile({super.key, required this.transaction, this.onTap});

  final LedgerTransaction transaction;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semanticColors;
    final textTheme = Theme.of(context).textTheme;
    final isCredit = transaction.direction.isCredit;
    final isSpecial = transaction.kind != TransactionKind.standard;

    final amountColor = isCredit ? semantic.credit : semantic.debit;
    final sign = isCredit ? '+' : '−';

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: amountColor.withValues(alpha: 0.15),
        child: Icon(
          isSpecial
              ? Icons.sync_alt
              : (isCredit ? Icons.arrow_downward : Icons.arrow_upward),
          color: amountColor,
        ),
      ),
      title: Text(
        transaction.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        isSpecial
            ? _kindLabel(transaction.kind)
            : DateFormat.Hm().format(transaction.occurredAt.toLocal()),
        style: textTheme.bodySmall,
      ),
      trailing: Text(
        '$sign ${transaction.amount.format()}',
        style: textTheme.bodyLarge?.copyWith(
          color: amountColor,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }

  String _kindLabel(TransactionKind kind) => switch (kind) {
    TransactionKind.openingBalance => 'Saldo iniziale',
    TransactionKind.balanceAdjustment => 'Rettifica saldo',
    TransactionKind.standard => '',
    TransactionKind.unknown => '',
  };
}
