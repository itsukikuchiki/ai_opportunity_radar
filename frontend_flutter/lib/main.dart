import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/state/app_bootstrap_state.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final bootstrapState = AppBootstrapState();

  runApp(RadarApp(bootstrapState: bootstrapState));

  bootstrapState.init().catchError((_) {
    // AppBootstrapState 内部已经保存错误状态，
    // 这里吞掉未处理异常，避免首屏白屏或直接崩溃。
  });
}
