import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:financialmanager/app/session/current_user_provider.dart';
import 'package:financialmanager/features/ai/data/local/local_result_outbox.dart';
import 'package:financialmanager/features/ai/data/providers.dart';
import 'package:financialmanager/features/ai/domain/repositories/ai_repository.dart';
import 'package:financialmanager/features/authentication/domain/models/auth_user.dart';

class _Repo implements AiRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

class _Outbox implements LocalResultOutbox {
  final flushes = <String>[];

  @override
  Future<void> flush(AiRepository repo, String userId) async =>
      flushes.add(userId);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw UnimplementedError(invocation.memberName.toString());
}

const _user = AuthUser(
  id: 'u1',
  firstName: 'A',
  lastName: 'B',
  username: 'ab',
  email: 'a@b.c',
  emailVerified: true,
);

void main() {
  testWidgets('pending results go out at sign-in and on resume', (
    tester,
  ) async {
    final outbox = _Outbox();
    final c = ProviderContainer(
      overrides: [
        aiRepositoryProvider.overrideWithValue(_Repo()),
        localResultOutboxProvider.overrideWithValue(outbox),
      ],
    );
    addTearDown(c.dispose);
    c.read(localOutboxFlusherProvider);
    expect(outbox.flushes, isEmpty, reason: 'nobody signed in');

    c.read(currentUserProvider.notifier).state = _user;
    await tester.pump();
    expect(outbox.flushes, ['u1']);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(outbox.flushes, ['u1', 'u1']);

    c.read(currentUserProvider.notifier).state = null;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(outbox.flushes, ['u1', 'u1'], reason: 'signed out');
  });
}
