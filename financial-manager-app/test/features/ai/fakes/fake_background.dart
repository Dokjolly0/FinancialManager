import 'dart:async';

import 'package:financialmanager/features/ai/data/local/ai_notifier.dart';
import 'package:financialmanager/features/ai/data/local/background_work.dart';

/// Records what the app asks of the foreground service.
class FakeBackgroundWork implements BackgroundWork {
  final active = <String, BackgroundJob>{};
  final log = <String>[];
  final _buttons = StreamController<String>.broadcast();
  final _timeouts = StreamController<void>.broadcast();

  @override
  Future<void> begin(BackgroundJob job) async {
    active[job.id] = job;
    log.add('begin ${job.id}: ${job.text}');
  }

  @override
  void update(String id, String text) {
    final job = active[id];
    if (job == null) return;
    active[id] = BackgroundJob(id: id, kind: job.kind, text: text);
    log.add('update $id: $text');
  }

  @override
  Future<void> end(String id) async {
    if (active.remove(id) != null) log.add('end $id');
  }

  void press(String button) => _buttons.add(button);

  void timeout() => _timeouts.add(null);

  @override
  Stream<String> get buttonPresses => _buttons.stream;

  @override
  Stream<void> get timeouts => _timeouts.stream;
}

class FakeAiNotifier implements AiNotifier {
  final shown = <({String title, String body, String? route})>[];

  @override
  Future<void> init({
    required String channelName,
    required void Function(String route) onOpen,
  }) async {}

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? route,
  }) async => shown.add((title: title, body: body, route: route));
}
