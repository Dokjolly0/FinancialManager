import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:financialmanager/app/app.dart';
import 'package:financialmanager/app/placeholder_screen.dart';
import 'package:financialmanager/app/router.dart';

void main() {
  testWidgets('App boots and redirects an unauthenticated session to login', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: FinancialManagerApp()));
    await tester.pumpAndSettle();

    expect(find.byType(FeaturePlaceholderScreen), findsOneWidget);
    expect(find.text(AppRoutes.login), findsOneWidget);
  });
}
