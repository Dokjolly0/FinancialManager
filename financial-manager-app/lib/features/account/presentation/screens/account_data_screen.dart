import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/session/session_controller.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/app_error.dart';
import '../../../../core/errors/error_presentation.dart';
import '../../../../core/widgets/confirmation_sheet.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../authentication/presentation/widgets/password_field.dart';
import '../view_models/data_controller.dart';

/// Dati (plan.md section 7.13, 20.2, 20.3): esporta CSV/JSON, elimina
/// account.
class AccountDataScreen extends ConsumerWidget {
  const AccountDataScreen({super.key});

  Future<void> _export(
    BuildContext context,
    WidgetRef ref,
    String format,
  ) async {
    await ref.read(dataControllerProvider.notifier).requestExport(format);
    if (!context.mounted) return;

    final state = ref.read(dataControllerProvider);
    final l10n = AppLocalizations.of(context);
    if (state.savedFilePath != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.exportSavedMessage(state.savedFilePath!))),
      );
    } else if (state.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(presentError(state.error!, l10n).message)),
      );
    }
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final warned = await ConfirmationSheet.show(
      context,
      title: l10n.deleteAccountConfirmTitle,
      message: l10n.deleteAccountConfirmMessage,
      confirmLabel: l10n.commonContinue,
      isDestructive: true,
    );
    if (!warned || !context.mounted) return;

    final passwordController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.confirmPasswordDialogTitle),
        content: PasswordField(
          controller: passwordController,
          label: l10n.currentPasswordOptionalGoogleLabel,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.deleteAccountAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref
          .read(dataControllerProvider.notifier)
          .deleteAccount(
            currentPassword: passwordController.text.isEmpty
                ? null
                : passwordController.text,
          );
      ref.read(sessionControllerProvider.notifier).signOut();
    } on AppError catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              presentError(e, AppLocalizations.of(context)).message,
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dataControllerProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.accountDataMenuTitle)),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text(
            l10n.exportDataSectionTitle,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            l10n.exportDataDescription,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: state.isExporting
                      ? null
                      : () => _export(context, ref, 'csv'),
                  child: Text(l10n.exportCsvAction),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton(
                  onPressed: state.isExporting
                      ? null
                      : () => _export(context, ref, 'json'),
                  child: Text(l10n.exportJsonAction),
                ),
              ),
            ],
          ),
          if (state.isExporting)
            const Padding(
              padding: EdgeInsets.only(top: AppSpacing.md),
              child: Center(child: CircularProgressIndicator()),
            ),
          const SizedBox(height: AppSpacing.xl),
          const Divider(),
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n.dangerZoneTitle,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.error,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
              side: BorderSide(color: Theme.of(context).colorScheme.error),
            ),
            onPressed: () => _deleteAccount(context, ref),
            child: Text(l10n.deleteAccountAction),
          ),
        ],
      ),
    );
  }
}
