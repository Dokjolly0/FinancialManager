import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../l10n/app_localizations.dart';
import '../../data/providers.dart';
import '../../domain/models/category_sort.dart';

/// "A–Z / Più usate" switch for category lists. The choice is shared by
/// every list and remembered on the device ([categorySortProvider]).
class CategorySortToggle extends ConsumerWidget {
  const CategorySortToggle({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    return SegmentedButton<CategorySort>(
      showSelectedIcon: false,
      segments: [
        ButtonSegment(
          value: CategorySort.alphabetical,
          icon: const Icon(Icons.sort_by_alpha),
          label: Text(l10n.categorySortAlphabetical),
        ),
        ButtonSegment(
          value: CategorySort.mostUsed,
          icon: const Icon(Icons.trending_up),
          label: Text(l10n.categorySortMostUsed),
        ),
      ],
      selected: {ref.watch(categorySortProvider)},
      onSelectionChanged: (selection) =>
          ref.read(categorySortProvider.notifier).set(selection.single),
    );
  }
}
