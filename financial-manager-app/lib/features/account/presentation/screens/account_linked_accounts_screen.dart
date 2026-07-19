import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/widgets/confirmation_sheet.dart';
import '../../../../core/widgets/inline_error.dart';
import '../../../authentication/presentation/widgets/password_field.dart';
import '../../domain/models/linked_identity.dart';
import '../view_models/linked_accounts_controller.dart';

/// Account collegati (plan.md section 7.13, 14.3): Google collegato/non
/// collegato, con data ultimo utilizzo. Link/unlink richiedono
/// "autenticazione recente" — qui rappresentata dalla password attuale.
class AccountLinkedAccountsScreen extends ConsumerWidget {
  const AccountLinkedAccountsScreen({super.key});

  Future<void> _link(BuildContext context, WidgetRef ref) async {
    final passwordController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Conferma la password'),
        content: PasswordField(
          controller: passwordController,
          label: 'Password attuale',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annulla'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Continua'),
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
      SnackBar(content: Text(error ?? 'Google collegato con successo.')),
    );
  }

  Future<void> _unlink(BuildContext context, WidgetRef ref) async {
    final confirmed = await ConfirmationSheet.show(
      context,
      title: 'Scollegare Google?',
      message: 'Potrai comunque accedere con la tua password.',
      confirmLabel: 'Scollega',
      isDestructive: true,
    );
    if (!confirmed) return;

    final error = await ref
        .read(linkedAccountsControllerProvider.notifier)
        .unlinkGoogle();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? 'Google scollegato.')),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(linkedAccountsControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Account collegati')),
      body: state.isLoading
          ? const Center(child: CircularProgressIndicator())
          : state.error != null
          ? InlineError(
              message: state.error!,
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
                              state.identities.firstWhere(
                                (i) => i.provider == 'google',
                              ),
                            ),
                          )
                        : const Text('Non collegato'),
                    trailing: FilledButton.tonal(
                      onPressed: () => state.isGoogleLinked
                          ? _unlink(context, ref)
                          : _link(context, ref),
                      child: Text(
                        state.isGoogleLinked ? 'Scollega' : 'Collega',
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  String _lastUsedLabel(LinkedIdentity identity) {
    final lastUsedAt = identity.lastUsedAt;
    if (lastUsedAt == null) return 'Collegato, mai utilizzato';
    final formatted = DateFormat(
      'd MMM y, HH:mm',
      'it_IT',
    ).format(lastUsedAt.toLocal());
    return 'Ultimo utilizzo: $formatted';
  }
}
