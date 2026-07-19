import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/errors/app_error.dart';
import '../../../../core/errors/error_presentation.dart';
import '../../../../core/formatting/color_hex.dart';
import '../../../../core/widgets/generated_avatar.dart';
import '../../../../core/widgets/inline_error.dart';
import '../../../authentication/data/providers.dart';
import '../view_models/account_providers.dart';
import '../view_models/profile_controller.dart';

/// Profilo (plan.md section 7.13): nome, cognome, username (sola lettura,
/// univoco), email con stato di verifica, avatar.
class AccountProfileScreen extends ConsumerStatefulWidget {
  const AccountProfileScreen({super.key});

  @override
  ConsumerState<AccountProfileScreen> createState() =>
      _AccountProfileScreenState();
}

class _AccountProfileScreenState extends ConsumerState<AccountProfileScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  bool _synced = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final profile = ref.read(accountProfileProvider).valueOrNull;
    if (profile == null) return;

    setState(() => _isSaving = true);
    try {
      await ref
          .read(profileControllerProvider)
          .save(
            profile,
            firstName: _firstNameController.text.trim(),
            lastName: _lastNameController.text.trim(),
          );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profilo aggiornato.')));
      }
    } on AppError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(presentError(e).message)));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _resendVerification() async {
    try {
      await ref.read(authRepositoryProvider).resendVerification();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email di verifica inviata.')),
        );
      }
    } on AppError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(presentError(e).message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(accountProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Profilo')),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => InlineError(
          message: 'Impossibile caricare il profilo.',
          onRetry: () => ref.invalidate(accountProfileProvider),
        ),
        data: (profile) {
          if (!_synced) {
            _firstNameController.text = profile.firstName;
            _lastNameController.text = profile.lastName;
            _synced = true;
          }

          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: [
              Center(
                child: GeneratedAvatar(
                  firstName: _firstNameController.text,
                  lastName: _lastNameController.text,
                  backgroundColor: colorFromHex(profile.avatarBackgroundColor),
                  textColor: colorFromHex(profile.avatarTextColor),
                  radius: 40,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _firstNameController,
                decoration: const InputDecoration(
                  labelText: 'Nome',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                controller: _lastNameController,
                decoration: const InputDecoration(
                  labelText: 'Cognome',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                enabled: false,
                controller: TextEditingController(text: profile.username),
                decoration: const InputDecoration(
                  labelText: 'Username',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextField(
                enabled: false,
                controller: TextEditingController(text: profile.email),
                decoration: InputDecoration(
                  labelText: 'Email',
                  border: const OutlineInputBorder(),
                  suffixIcon: profile.emailVerified
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : IconButton(
                          icon: const Icon(Icons.error_outline),
                          tooltip: 'Invia di nuovo la verifica',
                          onPressed: _resendVerification,
                        ),
                ),
              ),
              if (!profile.emailVerified)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    'Email non verificata. Tocca l\'icona per reinviare il link.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              const SizedBox(height: AppSpacing.lg),
              FilledButton(
                onPressed: _isSaving ? null : _save,
                child: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Salva'),
              ),
            ],
          );
        },
      ),
    );
  }
}
