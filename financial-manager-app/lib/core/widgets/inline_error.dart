import 'package:flutter/material.dart';

import '../../app/theme/app_spacing.dart';

/// Recoverable-error placeholder shown inline in a screen or list (plan.md
/// section 6.6 / 7.15), with an optional retry action. Distinct from a
/// snack bar: this is for "this whole screen/section failed to load", not
/// a transient toast.
class InlineError extends StatelessWidget {
  const InlineError({
    super.key,
    required this.message,
    this.onRetry,
    this.retryLabel = 'Riprova',
  });

  final String message;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 40, color: colorScheme.error),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.md),
              OutlinedButton(onPressed: onRetry, child: Text(retryLabel)),
            ],
          ],
        ),
      ),
    );
  }
}
