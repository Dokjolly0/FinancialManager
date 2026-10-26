import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:financialmanager/features/categories/data/local/category_sort_store.dart';
import 'package:financialmanager/features/categories/data/providers.dart';
import 'package:financialmanager/features/categories/domain/models/category.dart';
import 'package:financialmanager/features/categories/domain/models/category_sort.dart';
import 'package:financialmanager/features/categories/domain/repositories/category_repository.dart';
import 'package:financialmanager/features/categories/presentation/widgets/category_picker_sheet.dart';
import 'package:financialmanager/l10n/app_localizations.dart';

class _Repo implements CategoryRepository {
  @override
  Future<List<Category>> listCategories() async => const [
    Category(
      id: 'c1',
      name: 'Palestra',
      directionScope: CategoryDirectionScope.debit,
      isSystem: false,
      sortOrder: 0,
    ),
    Category(
      id: 'c2',
      name: 'Svago',
      directionScope: CategoryDirectionScope.debit,
      isSystem: true,
      sortOrder: 7,
      hidden: true,
    ),
  ];

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _NoSortStore implements CategorySortStore {
  @override
  Future<CategorySort?> read() async => null;

  @override
  Future<void> write(CategorySort sort) async {}
}

/// Pumps a button that opens the picker through [open] and records what it
/// returned in [results].
Future<void> _pump(
  WidgetTester tester,
  Future<Object?> Function(BuildContext) open,
  List<Object?> results,
) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        categoryRepositoryProvider.overrideWithValue(_Repo()),
        categorySortStoreProvider.overrideWithValue(_NoSortStore()),
      ],
      child: MaterialApp(
        locale: const Locale('it'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => results.add(await open(context)),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('the transaction picker leaves hidden categories out', (
    tester,
  ) async {
    final results = <Object?>[];
    await _pump(tester, (c) => CategoryPickerSheet.show(c), results);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Palestra'), findsOneWidget);
    expect(find.text('Svago'), findsNothing);
    expect(find.text('Senza categoria'), findsNothing);
    expect(find.text('Nuova categoria'), findsOneWidget);

    await tester.tap(find.text('Palestra'));
    await tester.pumpAndSettle();
    expect((results.single as Category).id, 'c1');
  });

  testWidgets('the filter picker offers all, uncategorized and hidden ones', (
    tester,
  ) async {
    final results = <Object?>[];
    await _pump(tester, CategoryPickerSheet.showFilter, results);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Tutte le categorie'), findsOneWidget);
    expect(find.text('Svago'), findsOneWidget);
    expect(find.text('Nuova categoria'), findsNothing);

    await tester.tap(find.text('Senza categoria'));
    await tester.pumpAndSettle();
    expect(results.single, (categoryId: uncategorizedFilterId));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tutte le categorie'));
    await tester.pumpAndSettle();
    expect(results.last, (categoryId: null));
  });

  testWidgets('dismissing the filter picker returns null', (tester) async {
    final results = <Object?>[];
    await _pump(tester, CategoryPickerSheet.showFilter, results);
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(results.single, isNull);
  });
}
