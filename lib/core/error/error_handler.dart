import 'package:flutter/foundation.dart';

class AppErrorHandler {
  const AppErrorHandler._();

  static void initialize() {
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      report(details.exception, details.stack ?? StackTrace.current);
    };

    PlatformDispatcher.instance.onError = (error, stack) {
      report(error, stack);
      return true;
    };
  }

  static void report(Object error, StackTrace stack) {
    if (kDebugMode) {
      debugPrint('Unhandled application error: $error');
      debugPrintStack(stackTrace: stack);
    }

    // Production crash reporting (for example Sentry or Crashlytics) can be
    // connected here later without changing every feature.
  }
}
