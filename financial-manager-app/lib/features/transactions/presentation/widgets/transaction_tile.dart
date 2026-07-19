import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/semantic_colors.dart';
import '../../domain/models/ledger_transaction.dart';
import '../../domain/models/transaction_direction.dart';

/// A row in the recent-operations / history lists (plan.md section 6.6,
/// 7.5, 7.9). Direction is conveyed by icon, sign, and position — not
/// color alone (plan.md section 6.7).
class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.transaction,
    this.onTap,
    this.categoryName,
    this.imageUrl,
    this.imageHeaders = const {},
  });

  final LedgerTransaction transaction;
  final VoidCallback? onTap;

  /// Resolved from the transaction's category_id by the caller (plan.md
  /// section 7.9: "Ogni riga mostra ... titolo, categoria, ora e
  /// importo") — this widget doesn't know how to look categories up
  /// itself, so it stays usable without a Riverpod context in tests.
  final String? categoryName;

  /// Resolved from the transaction's media_id by the caller, same reason
  /// as [categoryName] — an authenticated `/v1/media/{id}` URL plus the
  /// headers needed to fetch it (plan.md section 16.7).
  final String? imageUrl;
  final Map<String, String> imageHeaders;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semanticColors;
    final textTheme = Theme.of(context).textTheme;
    final isCredit = transaction.direction.isCredit;
    final isSpecial = transaction.kind != TransactionKind.standard;

    final amountColor = isCredit ? semantic.credit : semantic.debit;
    final sign = isCredit ? '+' : '−';

    final time = DateFormat.Hm().format(transaction.occurredAt.toLocal());
    final subtitle = isSpecial
        ? _kindLabel(transaction.kind)
        : (categoryName != null ? '$categoryName · $time' : time);

    return ListTile(
      onTap: onTap,
      leading: imageUrl != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image(
                width: 40,
                height: 40,
                fit: BoxFit.cover,
                image: NetworkImage(imageUrl!, headers: imageHeaders),
              ),
            )
          : CircleAvatar(
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
      subtitle: Text(subtitle, style: textTheme.bodySmall),
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
