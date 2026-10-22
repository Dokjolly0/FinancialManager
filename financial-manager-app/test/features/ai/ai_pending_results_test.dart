import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:financialmanager/app/session/current_user_provider.dart';
import 'package:financialmanager/features/ai/data/local/local_result_outbox.dart';
import 'package:financialmanager/features/ai/data/providers.dart';
import 'package:financialmanager/features/ai/domain/models/ai_analysis.dart';
import 'package:financialmanager/features/ai/domain/models/local_model.dart';
import 'package:financialmanager/features/ai/domain/repositories/ai_repository.dart';
import 'package:financialmanager/features/ai/presentation/screens/ai_pending_results_screen.dart';
import 'package:financialmanager/features/authentication/domain/models/auth_user.dart';
import 'package:financialmanager/l10n/app_localizations.dart';

class _Repo implements AiRepository {
  final sent = <String>[];

  @override
  Future<AiMessage> submitLocalResult(
    String analysisId,
    String messageId,
    AiLocalResult result,
  ) async {
    sent.add(messageId);
    return AiMessage(
      id: messageId,
      kind: AiMessageKind.report,
      content: result.content,
      status: AiStatus.completed,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

AuthUser _user(String id) => AuthUser(
  id: id,
  firstName: 'A',
  lastName: 'B',
  username: id,
  email: '$id@x.it',
  emailVerified: true,
);

PendingLocalResult _item(String id, String owner, {String? refused}) =>
    PendingLocalResult(
      userId: owner,
      analysisId: 'a-$id',
      messageId: id,
      result: AiLocalResult(content: 'Testo $id', status: 'COMPLETED'),
      createdAt: DateTime.utc(2026, 10, 22, 9),
      ownerName: 'Utente $owner',
      modelLabel: 'Gemma 4 E2B · int4',
      refusedCode: refused,
    );

void main() {
  testWidgets('anyone reads; only the author sends or deletes', (tester) async {
    final outbox = MemoryLocalResultOutbox();
    await outbox.add(_item('m1', 'u1'));
    await outbox.add(_item('m2', 'u2', refused: 'NOT_FOUND'));
    final repo = _Repo();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          aiRepositoryProvider.overrideWithValue(repo),
          localResultOutboxProvider.overrideWithValue(outbox),
          currentUserProvider.overrideWith((ref) => _user('u1')),
        ],
        child: const MaterialApp(
          locale: Locale('it'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: AiPendingResultsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Report'), findsNWidgets(2));

    // Someone else's item: readable, not actionable.
    await tester.tap(find.textContaining('Utente u2'));
    await tester.pumpAndSettle();
    expect(find.text('Testo m2'), findsOneWidget);
    expect(find.textContaining('Rifiutato dal server'), findsOneWidget);
    expect(find.text('Solo Utente u2 può inviarlo o eliminarlo.'), findsOne);

    // The author's own item: send it now.
    await tester.tap(find.textContaining('Utente u1'));
    await tester.pumpAndSettle();
    expect(find.text('Testo m1'), findsOneWidget);
    await tester.tap(find.text('Invia ora'));
    await tester.pumpAndSettle();
    expect(repo.sent, ['m1']);
    expect((await outbox.pending()).map((i) => i.messageId), ['m2']);
  });
}
