import 'dart:async';

import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/diagnostics/privacy_safe_logger.dart';
import 'core/state/app_bootstrap_state.dart';

void main() {
  final logger = PrivacySafeLogger.instance;
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    logger.installFlutterHandlers();

    final bootstrapState = AppBootstrapState(logger: logger);
    try {
      await bootstrapState.prepareLaunch();
    } catch (error, stackTrace) {
      logger.capture(
        error,
        stackTrace,
        operation: 'prepare_launch',
      );
      // Initialization retries the preference read after the first frame.
    }

    runApp(RadarApp(bootstrapState: bootstrapState));

    unawaited(bootstrapState.init());
  }, (error, stackTrace) {
    logger.capture(
      error,
      stackTrace,
      operation: 'root_zone',
      fatal: true,
    );
  });
}
