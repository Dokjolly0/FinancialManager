import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/semantic_colors.dart';
import '../../../../l10n/app_localizations.dart';
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
    this.showDate = false,
    this.wrapTitle = false,
    this.currentLabel,
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

  /// Shows the full date next to the time instead of the time alone. The
  /// history and home lists group rows under a day header, so the time is
  /// enough there; lists that mix days (e.g. a payment group) need it.
  final bool showDate;

  /// Lets a long title wrap onto several lines instead of being cut with
  /// an ellipsis.
  final bool wrapTitle;

  /// When set, marks this row as the transaction currently being viewed:
  /// the row is highlighted, shows this text as a badge, and isn't
  /// tappable (there's nowhere to navigate to).
  final String? currentLabel;

  @override
  Widget build(BuildContext context) {
    final semantic = context.semanticColors;
    final textTheme = Theme.of(context).textTheme;
    final isCredit = transaction.direction.isCredit;
    final isSpecial = transaction.kind != TransactionKind.standard;

    final amountColor = isCredit ? semantic.credit : semantic.debit;
    final sign = isCredit ? '+' : '−';

    final l10n = AppLocalizations.of(context);
    final occurredAt = transaction.occurredAt.toLocal();
    final time = showDate
        ? DateFormat('d MMM y, HH:mm', 'it_IT').format(occurredAt)
        : DateFormat.Hm().format(occurredAt);
    final subtitle = isSpecial
        ? (showDate
              ? '${_kindLabel(l10n, transaction.kind)} · $time'
              : _kindLabel(l10n, transaction.kind))
        : (categoryName != null ? '$categoryName · $time' : time);
    final isCurrent = currentLabel != null;
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      onTap: isCurrent ? null : onTap,
      selected: isCurrent,
      selectedTileColor: colorScheme.primaryContainer.withValues(alpha: 0.4),
      selectedColor: colorScheme.onSurface,
      minVerticalPadding: wrapTitle ? AppSpacing.sm : null,
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
        maxLines: wrapTitle ? null : 1,
        overflow: wrapTitle ? null : TextOverflow.ellipsis,
      ),
      subtitle: isCurrent
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(subtitle, style: textTheme.bodySmall),
                const SizedBox(height: AppSpacing.grid),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xs,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(AppSpacing.xs),
                  ),
                  child: Text(
                    currentLabel!,
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onPrimary,
                    ),
                  ),
                ),
              ],
            )
          : Text(subtitle, style: textTheme.bodySmall),
      trailing: Text(
        '$sign ${transaction.amount.format()}',
        style: textTheme.bodyLarge?.copyWith(
          color: amountColor,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }

  String _kindLabel(AppLocalizations l10n, TransactionKind kind) =>
      switch (kind) {
        TransactionKind.openingBalance => l10n.openingBalanceKindLabel,
        TransactionKind.balanceAdjustment => l10n.balanceAdjustmentKindLabel,
        TransactionKind.transfer => l10n.transferKindLabel,
        TransactionKind.standard => '',
        TransactionKind.unknown => '',
      };
}
