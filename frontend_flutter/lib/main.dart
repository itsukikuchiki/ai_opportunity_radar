import 'package:flutter/material.dart';
import 'app/app.dart';
import 'core/state/app_bootstrap_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final bootstrapState = AppBootstrapState();
  await bootstrapState.init();

  runApp(RadarApp(bootstrapState: bootstrapState));
}
