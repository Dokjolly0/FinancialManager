import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'router.dart';

/// The persistent bottom navigation (plan.md section 5.1): four
/// destinations plus a prominent center "Aggiungi" button, which pushes
/// the new-transaction screen rather than being a fifth tab.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(AppRoutes.transactionsNew),
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
