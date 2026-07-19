import 'package:flutter/material.dart';

import '../../app/theme/app_spacing.dart';
import '../../l10n/app_localizations.dart';

/// Full-width bottom sheet used to confirm an important or destructive
/// action (plan.md section 6.6, 7.10: transaction deletion, balance
/// adjustment). Returns `true` if confirmed, `false`/`null` if dismissed.
class ConfirmationSheet extends StatelessWidget {
  const ConfirmationSheet({
    super.key,
    required this.title,
    this.message,
    this.confirmLabel,
    this.cancelLabel,
    this.isDestructive = false,
  });

  final String title;
  final String? message;
  final String? confirmLabel;
  final String? cancelLabel;
  final bool isDestructive;

  /// Shows the sheet and returns the user's choice.
  static Future<bool> show(
    BuildContext context, {
    required String title,
    String? message,
    String? confirmLabel,
    String? cancelLabel,
    bool isDestructive = false,
  }) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      // Without this, the sheet is inserted into the shell branch's own
      // nested Navigator (StatefulShellRoute.indexedStack) instead of the
      // root one — AppShell's centerDocked FAB then paints and hit-tests
      // above it, so a button under the FAB's screen position is
      // unreachable.
      useRootNavigator: true,
      showDragHandle: true,
      builder: (context) => ConfirmationSheet(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        isDestructive: isDestructive,
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context);
    final resolvedConfirmLabel = confirmLabel ?? l10n.commonConfirm;
    final resolvedCancelLabel = cancelLabel ?? l10n.commonCancel;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.xs,
          AppSpacing.md,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                message!,
                style: textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              style: isDestructive
                  ? FilledButton.styleFrom(backgroundColor: colorScheme.error)
                  : null,
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(resolvedConfirmLabel),
            ),
            const SizedBox(height: AppSpacing.xs),
            OutlinedButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(resolvedCancelLabel),
            ),
          ],
        ),
      ),
    );
  }
}
