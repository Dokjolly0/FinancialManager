import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../core/observability/app_logger.dart';

/// Single entry point for starting the app: wires Flutter/Dart error
/// handlers to [AppLogger] before anything else runs, so early failures are
/// captured the same way as everything else (plan.md section 9.2/22.4:
/// crash reporting is an abstraction, swapped for a real provider later
/// without touching this call site).
Future<void> bootstrap(Widget Function() appBuilder) async {
  final logger = const DeveloperLogger();

  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      await initializeDateFormatting('it_IT');

      FlutterError.onError = (details) {
        logger.error(
          'flutter_error',
          error: details.exception,
          stackTrace: details.stack,
        );
      };

      runApp(ProviderScope(child: appBuilder()));
    },
    (error, stackTrace) {
      logger.error('uncaught_zone_error', error: error, stackTrace: stackTrace);
    },
  );
}
