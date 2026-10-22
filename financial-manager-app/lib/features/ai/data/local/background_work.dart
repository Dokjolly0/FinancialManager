import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// What keeps the app working while it isn't on screen (plan.md section
/// 33.9): model downloads and on-device analyses.
enum BackgroundJobKind { download, generation }

class BackgroundJob {
  const BackgroundJob({
    required this.id,
    required this.kind,
    required this.text,
  });

  final String id;
  final BackgroundJobKind kind;

  /// The job's line in the notification, already localized.
  final String text;
}

/// Buttons of the work notification.
abstract final class BackgroundButtons {
  static const pause = 'pause';
  static const stop = 'stop';
}

/// Localized texts of the work notification.
class BackgroundTexts {
  const BackgroundTexts({
    required this.title,
    required this.channel,
    required this.pause,
    required this.stop,
  });

  final String title;
  final String channel;
  final String pause;
  final String stop;
}

/// Runs the app as a foreground service while there is work: the service
/// starts with the first job and stops with the last, and its notification
/// lists the jobs with a Pausa button for downloads and an Interrompi
/// button for analyses.
abstract interface class BackgroundWork {
  /// Starts (or updates) [job].
  Future<void> begin(BackgroundJob job);

  /// Replaces a running job's line; ignored for unknown jobs.
  void update(String id, String text);

  Future<void> end(String id);

  /// Ids of the notification buttons pressed ([BackgroundButtons]).
  Stream<String> get buttonPresses;

  /// The system stopped the service (Android 15+ allows dataSync services
  /// 6 hours a day).
  Stream<void> get timeouts;
}

/// Where there is no foreground service (iOS, tests): nothing happens.
class NoopBackgroundWork implements BackgroundWork {
  const NoopBackgroundWork();

  @override
  Future<void> begin(BackgroundJob job) async {}

  @override
  void update(String id, String text) {}

  @override
  Future<void> end(String id) async {}

  @override
  Stream<String> get buttonPresses => const Stream.empty();

  @override
  Stream<void> get timeouts => const Stream.empty();
}

/// Whether the app is on screen now (true where there is no binding).
bool appInForeground() {
  try {
    final state = WidgetsBinding.instance.lifecycleState;
    return state == null || state == AppLifecycleState.resumed;
  } catch (_) {
    return true;
  }
}

/// Android: flutter_foreground_task's service. The work itself stays in
/// the main isolate (the cached engine keeps it alive, see
/// FinancialManagerApplication); the service only keeps the process, the
/// CPU and Wi-Fi awake and shows progress.
class ForegroundTaskBackgroundWork implements BackgroundWork {
  ForegroundTaskBackgroundWork(this._texts);

  final BackgroundTexts Function() _texts;
  final _jobs = <String, BackgroundJob>{};
  final _buttons = StreamController<String>.broadcast();
  final _timeouts = StreamController<void>.broadcast();
  bool _initialized = false;
  bool _running = false;
  bool _askedPermission = false;
  Timer? _throttle;
  DateTime _lastPush = DateTime.fromMillisecondsSinceEpoch(0);
  Future<void> _pending = Future.value();

  static const _serviceId = 4221;
  static const _minInterval = Duration(seconds: 1);

  @override
  Stream<String> get buttonPresses => _buttons.stream;

  @override
  Stream<void> get timeouts => _timeouts.stream;

  @override
  Future<void> begin(BackgroundJob job) {
    _jobs[job.id] = job;
    return _serial(() async {
      if (_running) return _push(force: true);
      await _start();
    });
  }

  @override
  void update(String id, String text) {
    final job = _jobs[id];
    if (job == null || job.text == text) return;
    _jobs[id] = BackgroundJob(id: id, kind: job.kind, text: text);
    final wait = _minInterval - DateTime.now().difference(_lastPush);
    if (wait <= Duration.zero) {
      unawaited(_serial(() => _push()));
    } else {
      _throttle ??= Timer(wait, () {
        _throttle = null;
        unawaited(_serial(() => _push()));
      });
    }
  }

  @override
  Future<void> end(String id) {
    if (_jobs.remove(id) == null) return Future.value();
    return _serial(() async {
      if (_jobs.isEmpty) {
        _throttle?.cancel();
        _throttle = null;
        if (_running) {
          _running = false;
          await FlutterForegroundTask.stopService();
        }
      } else {
        await _push(force: true);
      }
    });
  }

  Future<void> _serial(Future<void> Function() action) {
    final next = _pending.then((_) => action()).catchError((_) {});
    _pending = next;
    return next;
  }

  Future<void> _start() async {
    if (_jobs.isEmpty) return;
    final texts = _texts();
    if (!_initialized) {
      FlutterForegroundTask.init(
        androidNotificationOptions: AndroidNotificationOptions(
          channelId: 'ai_background_work',
          channelName: texts.channel,
          onlyAlertOnce: true,
        ),
        iosNotificationOptions: const IOSNotificationOptions(
          showNotification: false,
        ),
        foregroundTaskOptions: ForegroundTaskOptions(
          eventAction: ForegroundTaskEventAction.nothing(),
          allowWakeLock: true,
          allowWifiLock: true,
          // A restarted service would have no work: the work is in the
          // main isolate.
          allowAutoRestart: false,
          stopWithTask: false,
        ),
      );
      FlutterForegroundTask.addTaskDataCallback(_onTaskData);
      _initialized = true;
    }
    if (!_askedPermission) {
      _askedPermission = true;
      try {
        if (await FlutterForegroundTask.checkNotificationPermission() !=
            NotificationPermission.granted) {
          // Refused: the service runs anyway, its notification is hidden.
          await FlutterForegroundTask.requestNotificationPermission();
        }
      } catch (_) {}
    }
    if (await FlutterForegroundTask.isRunningService) {
      _running = true;
      return _push(force: true);
    }
    final result = await FlutterForegroundTask.startService(
      serviceId: _serviceId,
      serviceTypes: const [
        ForegroundServiceTypes.dataSync,
        ForegroundServiceTypes.specialUse,
      ],
      notificationTitle: texts.title,
      notificationText: _text(),
      notificationButtons: _notificationButtons(texts),
      callback: backgroundWorkTaskCallback,
    );
    _running = result is ServiceRequestSuccess;
    _lastPush = DateTime.now();
  }

  Future<void> _push({bool force = false}) async {
    if (!_running || _jobs.isEmpty) return;
    if (!force && DateTime.now().difference(_lastPush) < _minInterval) return;
    _lastPush = DateTime.now();
    await FlutterForegroundTask.updateService(
      notificationTitle: _texts().title,
      notificationText: _text(),
      notificationButtons: _notificationButtons(_texts()),
    );
  }

  String _text() => _jobs.values.map((j) => j.text).join(' · ');

  List<NotificationButton> _notificationButtons(BackgroundTexts texts) => [
    if (_jobs.values.any((j) => j.kind == BackgroundJobKind.download))
      NotificationButton(id: BackgroundButtons.pause, text: texts.pause),
    if (_jobs.values.any((j) => j.kind == BackgroundJobKind.generation))
      NotificationButton(id: BackgroundButtons.stop, text: texts.stop),
  ];

  void _onTaskData(Object data) {
    if (data is! Map) return;
    final button = data['button'];
    if (button is String) _buttons.add(button);
    if (data['timeout'] == true) {
      _running = false;
      _timeouts.add(null);
    }
  }
}

/// The service's own isolate: it only relays notification events to the
/// main isolate, where the work runs.
@pragma('vm:entry-point')
void backgroundWorkTaskCallback() {
  FlutterForegroundTask.setTaskHandler(_RelayTaskHandler());
}

class _RelayTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    if (isTimeout) FlutterForegroundTask.sendDataToMain({'timeout': true});
  }

  @override
  void onNotificationButtonPressed(String id) =>
      FlutterForegroundTask.sendDataToMain({'button': id});

  @override
  void onNotificationPressed() => FlutterForegroundTask.launchApp();
}
