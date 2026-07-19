import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/error_presentation.dart';
import '../../../../core/widgets/confirmation_sheet.dart';
import '../../../../core/widgets/inline_error.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../authentication/presentation/widgets/password_field.dart';
import '../../domain/models/linked_identity.dart';
import '../view_models/linked_accounts_controller.dart';

/// Account collegati (plan.md section 7.13, 14.3): Google collegato/non
/// collegato, con data ultimo utilizzo. Link/unlink richiedono
/// "autenticazione recente" — qui rappresentata dalla password attuale.
class AccountLinkedAccountsScreen extends ConsumerWidget {
  const AccountLinkedAccountsScreen({super.key});

  Future<void> _link(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final passwordController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.confirmPasswordDialogTitle),
        content: PasswordField(
          controller: passwordController,
          label: l10n.currentPasswordLabel,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.commonContinue),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final error = await ref
        .read(linkedAccountsControllerProvider.notifier)
        .linkGoogle(passwordController.text);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error == null
              ? l10n.googleLinkedSuccessMessage
              : presentError(error, l10n).message,
        ),
      ),
    );
  }

  Future<void> _unlink(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await ConfirmationSheet.show(
      context,
      title: l10n.unlinkGoogleConfirmTitle,
      message: l10n.unlinkGoogleConfirmMessage,
      confirmLabel: l10n.unlinkGoogleAction,
      isDestructive: true,
    );
    if (!confirmed) return;

    final error = await ref
        .read(linkedAccountsControllerProvider.notifier)
        .unlinkGoogle();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          error == null
              ? l10n.googleUnlinkedSuccessMessage
              : presentError(error, l10n).message,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(linkedAccountsControllerProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.accountLinkedAccountsMenuTitle)),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.error != null
          ? InlineError(
              message: presentError(state.error!, l10n).message,
              onRetry: () =>
                  ref.read(linkedAccountsControllerProvider.notifier).refresh(),
            )
          : ListView(
              padding: const EdgeInsets.all(AppSpacing.md),
              children: [
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.g_mobiledata, size: 32),
                    title: const Text('Google'),
                    subtitle: state.isGoogleLinked
                        ? Text(
                            _lastUsedLabel(
                              l10n,
                              state.identities.firstWhere(
                                (i) => i.provider == 'google',
                              ),
                            ),
                          )
                        : Text(l10n.notLinkedLabel),
                    trailing: FilledButton.tonal(
                      onPressed: () => state.isGoogleLinked
                          ? _unlink(context, ref)
                          : _link(context, ref),
                      child: Text(
                        state.isGoogleLinked ? l10n.unlinkGoogleAction : l10n.linkAction,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  String _lastUsedLabel(AppLocalizations l10n, LinkedIdentity identity) {
    final lastUsedAt = identity.lastUsedAt;
    if (lastUsedAt == null) return l10n.linkedNeverUsedLabel;
    final formatted = DateFormat(
      'd MMM y, HH:mm',
      'it_IT',
    ).format(lastUsedAt.toLocal());
    return l10n.lastUsedLabel(formatted);
  }
}
