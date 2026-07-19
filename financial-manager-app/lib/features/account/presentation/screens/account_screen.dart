import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/router.dart';
import '../../../../app/session/session_controller.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/formatting/color_hex.dart';
import '../../../../core/widgets/confirmation_sheet.dart';
import '../../../../core/widgets/generated_avatar.dart';
import '../../../../core/widgets/inline_error.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../authentication/data/providers.dart';
import '../view_models/account_providers.dart';
import '../widgets/balance_adjustment_sheet.dart';

/// Account (plan.md section 7.13): profile summary, wallet + rettifica,
/// and a menu into Sicurezza/Account collegati/Preferenze/Dati, plus
/// logout.
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await ConfirmationSheet.show(
      context,
      title: l10n.accountLogoutConfirmTitle,
      confirmLabel: l10n.accountLogoutAction,
    );
    if (!confirmed) return;
    await ref.read(authRepositoryProvider).logout();
    ref.read(sessionControllerProvider.notifier).signOut();
  }

  Future<void> _logoutAll(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await ConfirmationSheet.show(
      context,
      title: l10n.accountLogoutAllConfirmTitle,
      message: l10n.accountLogoutAllConfirmMessage,
      confirmLabel: l10n.accountLogoutAllAction,
      isDestructive: true,
    );
    if (!confirmed) return;
    await ref.read(authRepositoryProvider).logoutAll();
    ref.read(sessionControllerProvider.notifier).signOut();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(accountProfileProvider);
    final walletAsync = ref.watch(accountWalletProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.accountScreenTitle)),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(accountProfileProvider);
          ref.invalidate(accountWalletProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            profileAsync.when(
              loading: () => const SizedBox(
                height: 80,
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, _) => InlineError(
                message: l10n.accountProfileLoadError,
                onRetry: () => ref.invalidate(accountProfileProvider),
              ),
              data: (profile) => Card(
                child: ListTile(
                  leading: GeneratedAvatar(
                    firstName: profile.firstName,
                    lastName: profile.lastName,
                    backgroundColor: colorFromHex(
                      profile.avatarBackgroundColor,
                    ),
                    textColor: colorFromHex(profile.avatarTextColor),
                  ),
                  title: Text('${profile.firstName} ${profile.lastName}'),
                  subtitle: Text('@${profile.username}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRoutes.accountProfile),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            walletAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
              data: (wallet) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.accountWalletLabel,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            wallet.balance.format(),
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          OutlinedButton(
                            onPressed: () => BalanceAdjustmentSheet.show(
                              context,
                              wallet.balance,
                            ),
                            child: Text(l10n.accountBalanceAdjustmentAction),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.shield_outlined),
                    title: Text(l10n.accountSecurityMenuTitle),
                    subtitle: Text(l10n.accountSecurityMenuSubtitle),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(AppRoutes.accountSecurity),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.link),
                    title: Text(l10n.accountLinkedAccountsMenuTitle),
                    subtitle: const Text('Google'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () =>
                        context.push(AppRoutes.accountLinkedAccounts),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.tune),
                    title: Text(l10n.accountPreferencesMenuTitle),
                    subtitle: Text(l10n.accountPreferencesMenuSubtitle),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(AppRoutes.accountPreferences),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.folder_outlined),
                    title: Text(l10n.accountDataMenuTitle),
                    subtitle: Text(l10n.accountDataMenuSubtitle),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(AppRoutes.accountData),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.logout),
                    title: Text(l10n.accountLogoutAction),
                    onTap: () => _logout(context, ref),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.logout_outlined),
                    title: Text(l10n.accountLogoutAllMenuTitle),
                    onTap: () => _logoutAll(context, ref),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
