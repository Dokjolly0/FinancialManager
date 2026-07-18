import 'package:flutter/material.dart';

import '../../app/theme/app_spacing.dart';
import '../formatting/money.dart';

/// The prominent balance display (plan.md section 6.6, 7.5). Balance can
/// be hidden — the eye toggle — without leaving the screen; hiding is
/// purely a display concern, not a re-fetch.
class BalanceCard extends StatelessWidget {
  const BalanceCard({
    super.key,
    required this.balance,
    this.obscured = false,
    this.onToggleObscured,
    this.onTap,
    this.label = 'Saldo disponibile',
    this.updatedLabel,
  });

  final Money balance;
  final bool obscured;
  final VoidCallback? onToggleObscured;
  final VoidCallback? onTap;
  final String label;
  final String? updatedLabel;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      obscured ? '••••••' : balance.format(),
                      style: textTheme.displayLarge,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (onToggleObscured != null)
                    IconButton(
                      onPressed: onToggleObscured,
                      icon: Icon(
                        obscured
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                      tooltip: obscured ? 'Mostra saldo' : 'Nascondi saldo',
                    ),
                ],
              ),
              if (updatedLabel != null)
                Text(
                  updatedLabel!,
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
