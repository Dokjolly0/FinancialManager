import 'package:financialmanager/app/app_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

Widget _app() {
  StatefulShellBranch branch(String path) => StatefulShellBranch(
    routes: [GoRoute(path: path, builder: (_, _) => Text('page $path'))],
  );
  final router = GoRouter(
    initialLocation: '/a',
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(navigationShell: shell),
        branches: [branch('/a'), branch('/b'), branch('/c'), branch('/d')],
      ),
    ],
  );
  return ProviderScope(child: MaterialApp.router(routerConfig: router));
}

Future<void> _pumpAt(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(_app());
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('narrow width: bottom bar, no rail', (tester) async {
    // 600 rather than a phone's 400: the test font is much wider than
    // the real one and would overflow the bar's labels.
    await _pumpAt(tester, const Size(600, 800));
    expect(find.byType(BottomAppBar), findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
  });

  testWidgets('desktop width: side rail switches tabs', (tester) async {
    await _pumpAt(tester, const Size(1000, 800));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(BottomAppBar), findsNothing);
    expect(find.text('page /a'), findsOneWidget);
    await tester.tap(find.text('Report'));
    await tester.pumpAndSettle();
    expect(find.text('page /c'), findsOneWidget);
  });

  testWidgets('wide desktop: extended rail with "Aggiungi"', (tester) async {
    await _pumpAt(tester, const Size(1400, 900));
    expect(
      tester.widget<NavigationRail>(find.byType(NavigationRail)).extended,
      isTrue,
    );
    expect(find.text('Aggiungi'), findsOneWidget);
  });
}
