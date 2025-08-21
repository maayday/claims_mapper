// lib/logger.dart

/// Minimal logger we can swap in tests with a mock.
/// We only use what we need: info, warn, error.
abstract class Logger {
  void info(String message, {Map<String, Object?> context = const {}});
  void warn(String message, {Map<String, Object?> context = const {}});
  void error(String message, {Map<String, Object?> context = const {}});
}

/// Default no-op logger (does nothing). Safe for production libs.
class NoopLogger implements Logger {
  @override
  void info(String message, {Map<String, Object?> context = const {}}) {}

  @override
  void warn(String message, {Map<String, Object?> context = const {}}) {}

  @override
  void error(String message, {Map<String, Object?> context = const {}}) {}
}
class ConsoleLogger implements Logger {
  void _p(String level, String message, Map<String, Object?> context) {
    if (context.isEmpty) {
      // ignore: avoid_print
      print('[$level] $message');
    } else {
      // ignore: avoid_print
      print('[$level] $message | context=$context');
    }
  }

  @override
  void info(String message, {Map<String, Object?> context = const {}}) =>
      _p('INFO', message, context);

  @override
  void warn(String message, {Map<String, Object?> context = const {}}) =>
      _p('WARN', message, context);

  @override
  void error(String message, {Map<String, Object?> context = const {}}) =>
      _p('ERROR', message, context);
}


