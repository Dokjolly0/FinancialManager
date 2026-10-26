import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:financialmanager/features/categories/data/local/category_sort_store.dart';
import 'package:financialmanager/features/categories/data/providers.dart';
import 'package:financialmanager/features/categories/domain/models/category.dart';
import 'package:financialmanager/features/categories/domain/models/category_sort.dart';
import 'package:financialmanager/features/categories/domain/repositories/category_repository.dart';
import 'package:financialmanager/features/categories/presentation/screens/categories_screen.dart';
import 'package:financialmanager/l10n/app_localizations.dart';

class _Repo implements CategoryRepository {
  _Repo(this.categories);

  List<Category> categories;
  final deleted = <String>[];
  final hiddenChanges = <(String, bool)>[];

  @override
  Future<List<Category>> listCategories() async => categories;

  @override
  Future<void> deleteCategory(String id) async {
    deleted.add(id);
    categories = categories.where((c) => c.id != id).toList();
  }

  @override
  Future<void> setCategoryHidden(String id, {required bool hidden}) async {
    hiddenChanges.add((id, hidden));
    categories = [
      for (final c in categories)
        c.id == id
            ? Category(
                id: c.id,
                name: c.name,
                directionScope: c.directionScope,
                isSystem: c.isSystem,
                sortOrder: c.sortOrder,
                usageCount: c.usageCount,
                hidden: hidden,
              )
            : c,
    ];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _MemorySortStore implements CategorySortStore {
  CategorySort? stored;

  @override
  Future<CategorySort?> read() async => stored;

  @override
  Future<void> write(CategorySort sort) async => stored = sort;
}

Category _category(
  String id,
  String name, {
  bool isSystem = false,
  int usageCount = 0,
  bool hidden = false,
  CategoryDirectionScope scope = CategoryDirectionScope.debit,
}) => Category(
  id: id,
  name: name,
  directionScope: scope,
  isSystem: isSystem,
  sortOrder: 0,
  usageCount: usageCount,
  hidden: hidden,
);

Future<void> _pump(WidgetTester tester, _Repo repo, _MemorySortStore store) {
  return tester.pumpWidget(
    ProviderScope(
      overrides: [
        categoryRepositoryProvider.overrideWithValue(repo),
        categorySortStoreProvider.overrideWithValue(store),
      ],
      child: MaterialApp(
        locale: const Locale('it'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const CategoriesScreen(),
      ),
    ),
  );
}

void main() {
  testWidgets('lists categories by section and remembers the sort', (
    tester,
  ) async {
    final repo = _Repo([
      _category('1', 'Zeta', usageCount: 1),
      _category('2', 'Alfa', usageCount: 0),
      _category(
        '3',
        'Stipendio',
        isSystem: true,
        usageCount: 4,
        scope: CategoryDirectionScope.credit,
      ),
      _category('4', 'Svago', isSystem: true, hidden: true),
    ]);
    final store = _MemorySortStore();
    await _pump(tester, repo, store);
    await tester.pumpAndSettle();

    expect(find.text('Uscite'), findsOneWidget);
    expect(find.text('Entrate'), findsOneWidget);
    expect(find.text('Nascoste'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Alfa')).dy,
      lessThan(tester.getTopLeft(find.text('Zeta')).dy),
    );

    await tester.tap(find.text('Più usate'));
    await tester.pumpAndSettle();
    expect(store.stored, CategorySort.mostUsed);
    expect(
      tester.getTopLeft(find.text('Zeta')).dy,
      lessThan(tester.getTopLeft(find.text('Alfa')).dy),
    );
  });

  testWidgets('deleting a used category warns about its transactions', (
    tester,
  ) async {
    final repo = _Repo([_category('1', 'Palestra', usageCount: 3)]);
    await _pump(tester, repo, _MemorySortStore());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Palestra'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elimina'));
    await tester.pumpAndSettle();

    expect(find.text('Eliminare «Palestra»?'), findsOneWidget);
    expect(
      find.text(
        '3 transazioni usano questa categoria: resteranno senza categoria.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Elimina'));
    await tester.pumpAndSettle();

    expect(repo.deleted, ['1']);
    expect(find.text('Palestra'), findsNothing);
  });

  testWidgets('a system category can be hidden and shown again', (
    tester,
  ) async {
    final repo = _Repo([_category('9', 'Svago', isSystem: true)]);
    await _pump(tester, repo, _MemorySortStore());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Svago'));
    await tester.pumpAndSettle();
    expect(find.text('Modifica'), findsNothing);
    await tester.tap(find.text('Nascondi'));
    await tester.pumpAndSettle();
    expect(find.text('Nascoste'), findsOneWidget);

    await tester.tap(find.text('Svago'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mostra di nuovo'));
    await tester.pumpAndSettle();

    expect(repo.hiddenChanges, [('9', true), ('9', false)]);
    expect(find.text('Nascoste'), findsNothing);
  });
}
