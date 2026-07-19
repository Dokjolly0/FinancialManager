import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/session/session_controller.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/app_error.dart';
import '../../../../core/errors/error_presentation.dart';
import '../../../../core/widgets/confirmation_sheet.dart';
import '../../../authentication/presentation/widgets/password_field.dart';
import '../view_models/data_controller.dart';

/// Dati (plan.md section 7.13, 20.2, 20.3): esporta CSV/JSON, elimina
/// account.
class AccountDataScreen extends ConsumerWidget {
  const AccountDataScreen({super.key});

  Future<void> _export(BuildContext context, WidgetRef ref, String format) async {
    await ref.read(dataControllerProvider.notifier).requestExport(format);
    if (!context.mounted) return;

    final state = ref.read(dataControllerProvider);
    if (state.savedFilePath != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Esportazione salvata in ${state.savedFilePath}')),
      );
    } else if (state.error != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(state.error!)));
    }
  }

  Future<void> _deleteAccount(BuildContext context, WidgetRef ref) async {
    final warned = await ConfirmationSheet.show(
      context,
      title: 'Eliminare l\'account?',
      message:
          'Questa azione è irreversibile. Il tuo profilo verrà rimosso; '
          'le operazioni registrate restano solo a fini contabili.',
      confirmLabel: 'Continua',
      isDestructive: true,
    );
    if (!warned || !context.mounted) return;

    final passwordController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Conferma la password'),
        content: PasswordField(
          controller: passwordController,
          label: 'Password attuale (vuota se solo Google)',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Elimina account'),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(presentError(e).message)));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(dataControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Dati')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text('Esporta i tuoi dati', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'CSV per le operazioni, JSON per profilo, portafoglio, '
            'categorie, modelli e operazioni.',
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
                  child: const Text('Esporta CSV'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton(
                  onPressed: state.isExporting
                      ? null
                      : () => _export(context, ref, 'json'),
                  child: const Text('Esporta JSON'),
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
            'Zona pericolosa',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
              side: BorderSide(color: Theme.of(context).colorScheme.error),
            ),
            onPressed: () => _deleteAccount(context, ref),
            child: const Text('Elimina account'),
          ),
        ],
      ),
    );
  }
}
