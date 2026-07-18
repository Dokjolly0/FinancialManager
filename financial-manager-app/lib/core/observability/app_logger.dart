import 'dart:developer' as developer;

/// Logging/crash-reporting abstraction independent of any specific provider
/// (plan.md section 9.2), so a real crash reporter (Sentry, Crashlytics,
/// ...) can be plugged in later without touching call sites.
///
/// Callers must never pass secrets, tokens, or full transaction descriptions
/// — see the same "no secrets in logs" rule the backend follows
/// (plan.md section 19.7 / 22.4).
abstract class AppLogger {
  void debug(String message, {Map<String, Object?>? context});
  void info(String message, {Map<String, Object?>? context});
  void warning(String message, {Map<String, Object?>? context});
  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? context,
  });
}

/// Default implementation: structured output via `dart:developer`, visible
/// in DevTools and `flutter logs` without pulling in a third-party SDK.
class DeveloperLogger implements AppLogger {
  const DeveloperLogger({this.name = 'financial_manager'});

  final String name;

  @override
  void debug(String message, {Map<String, Object?>? context}) =>
      _log(message, level: 500, context: context);

  @override
  void info(String message, {Map<String, Object?>? context}) =>
      _log(message, level: 800, context: context);

  @override
  void warning(String message, {Map<String, Object?>? context}) =>
      _log(message, level: 900, context: context);

  @override
  void error(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    Map<String, Object?>? context,
  }) {
    _log(
      message,
      level: 1000,
      context: context,
      error: error,
      stackTrace: stackTrace,
    );
  }

  void _log(
    String message, {
    required int level,
    Map<String, Object?>? context,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final suffix = context == null || context.isEmpty ? '' : ' $context';
    developer.log(
      '$message$suffix',
      name: name,
      level: level,
      error: error,
      stackTrace: stackTrace,
    );
  }
}
