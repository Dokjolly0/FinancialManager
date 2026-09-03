import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/wallets/data/providers.dart';
import '../features/wallets/domain/models/wallet.dart';
import '../features/wallets/presentation/widgets/transfer_sheet.dart';
import '../features/wallets/presentation/widgets/voucher_expense_sheet.dart';
import 'router.dart';

/// The persistent bottom navigation (plan.md section 5.1): four
/// destinations plus a prominent center "Aggiungi" button. Tapping it
/// opens a short menu — a plain income/expense, a wallet-to-wallet
/// transfer, or a meal-voucher expense — instead of being a fifth tab.
/// The transfer and voucher entries were previously buried in the
/// Account → Portafogli app bar; here they're one tap from every tab.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: navigationShell,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddMenu(context, ref),
        tooltip: 'Aggiungi operazione',
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _NavButton(
              icon: Icons.home_outlined,
              selectedIcon: Icons.home,
              label: 'Home',
              selected: navigationShell.currentIndex == 0,
              onTap: () => navigationShell.goBranch(0),
            ),
            _NavButton(
              icon: Icons.history_outlined,
              selectedIcon: Icons.history,
              label: 'Cronologia',
              selected: navigationShell.currentIndex == 1,
              onTap: () => navigationShell.goBranch(1),
            ),
            const SizedBox(width: 48),
            _NavButton(
              icon: Icons.bar_chart_outlined,
              selectedIcon: Icons.bar_chart,
              label: 'Report',
              selected: navigationShell.currentIndex == 2,
              onTap: () => navigationShell.goBranch(2),
            ),
            _NavButton(
              icon: Icons.person_outline,
              selectedIcon: Icons.person,
              label: 'Account',
              selected: navigationShell.currentIndex == 3,
              onTap: () => navigationShell.goBranch(3),
            ),
          ],
        ),
      ),
    );
  }
}

enum _AddAction { standard, transfer, voucher }

/// Opens the "Aggiungi" menu. With only plain income/expense available
/// (one wallet, no meal-voucher wallet) it skips the menu and goes
/// straight to the new-operation form.
Future<void> _showAddMenu(BuildContext context, WidgetRef ref) async {
  final wallets = ref.read(walletsListProvider).value ?? const <Wallet>[];
  final hasVoucherWallet = wallets.any((w) => w.isMealVoucher);
  final hasMultipleWallets = wallets.length >= 2;

  if (!hasVoucherWallet && !hasMultipleWallets) {
    context.push(AppRoutes.transactionsNew);
    return;
  }

  final action = await showModalBottomSheet<_AddAction>(
    context: context,
    useRootNavigator: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.swap_vert),
            title: const Text('Entrata / Uscita'),
            onTap: () => Navigator.of(context).pop(_AddAction.standard),
          ),
          if (hasMultipleWallets)
            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: const Text('Trasferisci tra portafogli'),
              onTap: () => Navigator.of(context).pop(_AddAction.transfer),
            ),
          if (hasVoucherWallet)
            ListTile(
              leading: const Icon(Icons.restaurant_outlined),
              title: const Text('Spesa con buoni pasto'),
              onTap: () => Navigator.of(context).pop(_AddAction.voucher),
            ),
        ],
      ),
    ),
  );

  if (action == null || !context.mounted) return;

  switch (action) {
    case _AddAction.standard:
      context.push(AppRoutes.transactionsNew);
    case _AddAction.transfer:
      await TransferSheet.show(context);
    case _AddAction.voucher:
      await VoucherExpenseSheet.show(context);
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(selected ? selectedIcon : icon, color: color),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.labelMedium?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
