import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Tells the user that background work finished (plan.md section 33.9):
/// an analysis written on the phone, a model downloaded. Only the
/// analysis title or the model name is shown, never the content. Tapping a
/// notification opens [route].
abstract interface class AiNotifier {
  /// [onOpen] receives the route of a tapped notification, also one that
  /// launched the app.
  Future<void> init({
    required String channelName,
    required void Function(String route) onOpen,
  });

  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? route,
  });
}

class NoopAiNotifier implements AiNotifier {
  const NoopAiNotifier();

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
  }) async {}
}

/// Android notifications through flutter_local_notifications.
class LocalAiNotifier implements AiNotifier {
  LocalAiNotifier({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  String _channelName = 'AI';
  bool _ready = false;

  static const _channelId = 'ai_results';

  @override
  Future<void> init({
    required String channelName,
    required void Function(String route) onOpen,
  }) async {
    _channelName = channelName;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (r) {
        final route = r.payload;
        if (route != null && route.isNotEmpty) onOpen(route);
      },
    );
    _ready = true;
    final launch = await _plugin.getNotificationAppLaunchDetails();
    final route = launch?.notificationResponse?.payload;
    if ((launch?.didNotificationLaunchApp ?? false) &&
        route != null &&
        route.isNotEmpty) {
      onOpen(route);
    }
  }

  @override
  Future<void> show({
    required int id,
    required String title,
    required String body,
    String? route,
  }) async {
    if (!_ready) return;
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      payload: route,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }
}
