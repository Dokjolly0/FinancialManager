import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:financialmanager/features/ai/data/providers.dart';
import 'package:financialmanager/features/ai/domain/models/ai_analysis_request.dart';
import 'package:financialmanager/features/ai/domain/models/ai_settings.dart';
import 'package:financialmanager/features/ai/presentation/screens/ai_analysis_setup_screen.dart';
import 'package:financialmanager/features/ai/presentation/view_models/ai_period.dart';
import 'package:financialmanager/features/categories/data/providers.dart';
import 'package:financialmanager/features/transactions/domain/repositories/transaction_repository.dart';
import 'package:financialmanager/features/wallets/data/providers.dart';
import 'package:financialmanager/l10n/app_localizations.dart';

void main() {
  group('aiQuickRange', () {
    final today = DateTime(2026, 2, 14, 18, 30);

    test('month and quarter shortcuts cross the year boundary', () {
      final jan = DateTime(2026, 1, 10);
      expect(aiQuickRange(AiQuickPeriod.lastMonth, jan), (
        from: DateTime(2025, 12),
        to: DateTime(2025, 12, 31),
      ));
      expect(aiQuickRange(AiQuickPeriod.lastQuarter, today), (
        from: DateTime(2025, 10),
        to: DateTime(2025, 12, 31),
      ));
      expect(aiQuickRange(AiQuickPeriod.lastQuarter, DateTime(2026, 8, 3)), (
        from: DateTime(2026, 4),
        to: DateTime(2026, 6, 30),
      ));
    });

    test('rolling ranges end today, ignoring the time of day', () {
      expect(aiQuickRange(AiQuickPeriod.last30Days, today), (
        from: DateTime(2026, 1, 16),
        to: DateTime(2026, 2, 14),
      ));
      expect(aiQuickRange(AiQuickPeriod.currentMonth, today), (
        from: DateTime(2026, 2),
        to: DateTime(2026, 2, 14),
      ));
      expect(aiQuickRange(AiQuickPeriod.currentYear, today), (
        from: DateTime(2026),
        to: DateTime(2026, 2, 14),
      ));
      expect(aiQuickRange(AiQuickPeriod.last12Months, today), (
        from: DateTime(2025, 2, 15),
        to: DateTime(2026, 2, 14),
      ));
      expect(aiQuickRange(AiQuickPeriod.allTime, today), (
        from: null,
        to: null,
      ));
    });

    test('a range matching a shortcut highlights it', () {
      expect(
        aiMatchQuick(aiQuickRange(AiQuickPeriod.lastMonth, today), today),
        AiQuickPeriod.lastMonth,
      );
      expect(
        aiMatchQuick((
          from: DateTime(2026, 1, 3),
          to: DateTime(2026, 1, 9),
        ), today),
        isNull,
      );
    });
  });

  test('aiPeriodFields: no bounds is the whole history, otherwise custom', () {
    expect(aiPeriodFields((from: null, to: null)).preset, 'all_time');
    final open = aiPeriodFields((from: DateTime(2026, 3, 1), to: null));
    expect(open.preset, 'custom');
    expect(open.to, isNull);

    final json = AiAnalysisRequest(
      preset: 'SAVINGS',
      periodPreset: open.preset,
      customFrom: open.from,
    ).toJson();
    expect(json['period'], {'preset': 'custom', 'from': '2026-03-01'});
  });

  group('aiPrefillFromHistory', () {
    test(
      'maps every Cronologia filter, turning the exclusive end inclusive',
      () {
        final result = aiPrefillFromHistory(
          TransactionListFilter(
            type: TransactionTypeFilter.debit,
            walletId: 'w1',
            title: '  sim ',
            categoryId: 'c1',
            amountMinMinor: 500,
            amountMaxMinor: 9000,
            occurredFrom: DateTime(2026, 6, 1),
            occurredTo: DateTime(2026, 7, 1),
          ),
        );
        final p = result.prefill!;
        expect(result.problem, isNull);
        expect(p.range, (
          from: DateTime(2026, 6, 1),
          to: DateTime(2026, 6, 30),
        ));
        expect(p.walletIds, ['w1']);
        expect(p.fromHistory, isTrue);
        expect(p.filters!.toJson(), {
          'direction': 'DEBIT',
          'category_id': 'c1',
          'title': 'sim',
          'amount_min_minor': 500,
          'amount_max_minor': 9000,
        });
      },
    );

    test('no filters: whole history, all wallets, empty filter', () {
      final p = aiPrefillFromHistory(const TransactionListFilter()).prefill!;
      expect(p.range, (from: null, to: null));
      expect(p.walletIds, isEmpty);
      expect(p.filters!.isEmpty, isTrue);
    });

    test('adjustments and transfers cannot be analyzed', () {
      expect(
        aiPrefillFromHistory(
          const TransactionListFilter(type: TransactionTypeFilter.adjustments),
        ).problem,
        AiHistoryPrefillProblem.adjustmentsOnly,
      );
      expect(
        aiPrefillFromHistory(
          const TransactionListFilter(type: TransactionTypeFilter.transfers),
        ).problem,
        AiHistoryPrefillProblem.transfersOnly,
      );
    });
  });

  test('an empty filter is not sent', () {
    const request = AiAnalysisRequest(
      preset: 'SAVINGS',
      filters: AiAnalysisFilters(title: '  '),
    );
    expect(
      (request.toJson()['options'] as Map).containsKey('filters'),
      isFalse,
    );
    const f = AiAnalysisFilters(direction: 'CREDIT', title: 'x');
    expect(f.without(direction: true).toJson(), {'title': 'x'});
  });

  testWidgets('the setup screen shows the Cronologia filters and dates', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        aiSettingsProvider.overrideWith(
          (ref) async => const AiSettings(
            available: true,
            active: AiCredential(
              id: 'c',
              provider: AiProviderKind.openai,
              model: 'm',
              hasKey: true,
            ),
            consent: AiConsent(currentVersion: 1, required: false),
            setup: AiSetupStatus(hasProvider: true, hasModel: true),
          ),
        ),
        aiPresetsProvider.overrideWith(
          (ref) async => [
            AiPreset.fromJson({
              'id': 'MONTHLY_CHECKUP',
              'title': 'Check-up',
              'default_sections': ['monthly'],
            }),
          ],
        ),
        walletsListProvider.overrideWith((ref) async => const []),
        categoriesProvider.overrideWith((ref) async => const []),
      ],
    );
    addTearDown(container.dispose);
    container
        .read(aiSetupPrefillProvider.notifier)
        .set(
          AiSetupPrefill(
            range: (from: DateTime(2026, 6, 1), to: DateTime(2026, 6, 30)),
            fromHistory: true,
            filters: const AiAnalysisFilters(direction: 'DEBIT', title: 'sim'),
          ),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          locale: Locale('it'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AiAnalysisSetupScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Filtri dalla Cronologia'), findsOneWidget);
    expect(find.text('Solo uscite'), findsOneWidget);
    expect(find.text('Contiene «sim»'), findsOneWidget);
    expect(find.text('1 giu 2026'), findsOneWidget);
    expect(find.text('30 giu 2026'), findsOneWidget);
    expect(
      container.read(aiSetupPrefillProvider),
      isNull,
      reason: 'the prefill is taken once',
    );

    // Removing a filter chip.
    await tester.tap(
      find.descendant(
        of: find.widgetWithText(InputChip, 'Solo uscite'),
        matching: find.byIcon(Icons.clear),
      ),
    );
    await tester.pump();
    expect(find.text('Solo uscite'), findsNothing);
    expect(find.text('Contiene «sim»'), findsOneWidget);

    // A shortcut fills both dates.
    await tester.ensureVisible(find.text('Tutta la cronologia'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tutta la cronologia'));
    await tester.pump();
    expect(find.text("Dall'inizio", skipOffstage: false), findsOneWidget);
    expect(find.text('Oggi', skipOffstage: false), findsOneWidget);
  });
}
