import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../app/session/session_controller.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/app_error.dart';
import '../../../../core/errors/error_presentation.dart';
import '../../../../core/widgets/confirmation_sheet.dart';
import '../../../../core/widgets/inline_error.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../authentication/data/providers.dart';
import '../../../authentication/presentation/widgets/password_field.dart';
import '../../data/providers.dart';
import '../../domain/models/account_session.dart';
import '../view_models/security_controller.dart';

/// Sicurezza (plan.md section 7.13): cambio password, sessioni attive,
/// logout da tutti i dispositivi.
class AccountSecurityScreen extends ConsumerStatefulWidget {
  const AccountSecurityScreen({super.key});

  @override
  ConsumerState<AccountSecurityScreen> createState() =>
      _AccountSecurityScreenState();
}

class _AccountSecurityScreenState extends ConsumerState<AccountSecurityScreen> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String? _passwordError;
  bool _isChangingPassword = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    final l10n = AppLocalizations.of(context);
    if (_newPasswordController.text.length < 8) {
      setState(() => _passwordError = l10n.errorCodePasswordTooShort);
      return;
    }
    if (_newPasswordController.text != _confirmPasswordController.text) {
      setState(() => _passwordError = l10n.errorCodePasswordsDoNotMatch);
      return;
    }

    setState(() {
      _passwordError = null;
      _isChangingPassword = true;
    });
    try {
      await ref
          .read(accountRepositoryProvider)
          .changePassword(
            currentPassword: _currentPasswordController.text,
            newPassword: _newPasswordController.text,
          );
      _currentPasswordController.clear();
      _newPasswordController.clear();
      _confirmPasswordController.clear();
      ref.invalidate(securityControllerProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Password aggiornata.')));
      }
    } on AppError catch (e) {
      final presented = presentError(e, l10n);
      if (mounted) {
        setState(
          () => _passwordError =
              presented.fieldErrors['current_password'] ?? presented.message,
        );
      }
    } finally {
      if (mounted) setState(() => _isChangingPassword = false);
    }
  }

  Future<void> _revoke(AccountSession session) async {
    final confirmed = await ConfirmationSheet.show(
      context,
      title: 'Terminare questa sessione?',
      message: session.deviceName ?? 'Dispositivo sconosciuto',
      confirmLabel: 'Termina',
      isDestructive: true,
    );
    if (!confirmed) return;
    await ref.read(securityControllerProvider.notifier).revoke(session.id);
  }

  Future<void> _logoutAll() async {
    final confirmed = await ConfirmationSheet.show(
      context,
      title: 'Uscire da tutti i dispositivi?',
      message: 'Tutte le sessioni attive verranno terminate, inclusa questa.',
      confirmLabel: 'Esci ovunque',
      isDestructive: true,
    );
    if (!confirmed) return;
    await ref.read(authRepositoryProvider).logoutAll();
    ref.read(sessionControllerProvider.notifier).signOut();
  }

  String _sessionLabel(AccountSession session) {
    final device = session.deviceName ?? 'Dispositivo sconosciuto';
    return session.platform == null ? device : '$device (${session.platform})';
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(securityControllerProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Sicurezza')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text(
            'Cambia password',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          PasswordField(
            controller: _currentPasswordController,
            label: 'Password attuale',
          ),
          const SizedBox(height: AppSpacing.sm),
          PasswordField(
            controller: _newPasswordController,
            label: 'Nuova password',
          ),
          const SizedBox(height: AppSpacing.sm),
          PasswordField(
            controller: _confirmPasswordController,
            label: 'Conferma nuova password',
            errorText: _passwordError,
          ),
          const SizedBox(height: AppSpacing.sm),
          FilledButton(
            onPressed: _isChangingPassword ? null : _changePassword,
            child: _isChangingPassword
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Aggiorna password'),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Sessioni attive',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              TextButton(
                onPressed: _logoutAll,
                child: const Text('Esci ovunque'),
              ),
            ],
          ),
          if (state.isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (state.error != null)
            InlineError(
              message: presentError(state.error!, l10n).message,
              onRetry: () =>
                  ref.read(securityControllerProvider.notifier).refresh(),
            )
          else
            for (final session in state.sessions)
              Card(
                child: ListTile(
                  leading: Icon(
                    session.isCurrent ? Icons.smartphone : Icons.devices_other,
                  ),
                  title: Text(_sessionLabel(session)),
                  subtitle: Text(
                    session.isCurrent
                        ? 'Questo dispositivo'
                        : 'Ultimo accesso: ${DateFormat('d MMM y, HH:mm', 'it_IT').format(session.lastUsedAt.toLocal())}',
                  ),
                  trailing: session.isCurrent
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close),
                          tooltip: 'Termina sessione',
                          onPressed: () => _revoke(session),
                        ),
                ),
              ),
        ],
      ),
    );
  }
}
