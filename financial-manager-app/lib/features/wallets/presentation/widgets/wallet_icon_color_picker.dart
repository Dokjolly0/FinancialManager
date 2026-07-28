import 'package:flutter/material.dart';

import '../../../../app/theme/app_spacing.dart';
import '../../../../core/formatting/color_hex.dart';
import '../../../../l10n/app_localizations.dart';
import 'wallet_icon_data.dart';

/// Icon + color picker used by the wallet create/edit form — a preview
/// circle plus two option grids, mirroring the registration screen's
/// avatar color-swatch pattern (built from scratch here per this
/// project's explicit request, since wallets need an icon choice too,
/// which avatars don't).
class WalletIconColorPicker extends StatelessWidget {
  const WalletIconColorPicker({
    super.key,
    required this.selectedIcon,
    required this.selectedColor,
    required this.onIconSelected,
    required this.onColorSelected,
  });

  final String selectedIcon;
  final Color selectedColor;
  final ValueChanged<String> onIconSelected;
  final ValueChanged<Color> onColorSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: CircleAvatar(
            radius: 36,
            backgroundColor: selectedColor,
            child: Icon(
              iconForWalletKey(selectedIcon),
              color: Colors.white,
              size: 32,
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          l10n.walletIconLabel,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: walletIconData.entries.map((entry) {
            final isSelected = entry.key == selectedIcon;
            return InkWell(
              onTap: () => onIconSelected(entry.key),
              customBorder: const CircleBorder(),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? Theme.of(context).colorScheme.secondaryContainer
                      : null,
                  border: isSelected
                      ? Border.all(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2,
                        )
                      : Border.all(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                ),
                child: Icon(entry.value),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          l10n.walletColorLabel,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: walletColorChoices.map((color) {
            final isSelected = colorToHex(color) == colorToHex(selectedColor);
            return InkWell(
              onTap: () => onColorSelected(color),
              customBorder: const CircleBorder(),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: isSelected
                      ? Border.all(color: Colors.black, width: 2)
                      : null,
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
