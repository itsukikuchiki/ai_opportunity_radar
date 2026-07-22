import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

Future<void> loadDesignQaFonts(String textFontFamily) async {
  final textFont = File('/System/Library/Fonts/Hiragino Sans GB.ttc');
  if (await textFont.exists()) {
    final bytes = await textFont.readAsBytes();
    await (FontLoader(textFontFamily)
          ..addFont(Future.value(ByteData.sublistView(bytes))))
        .load();
  }

  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  final iconCandidates = <File>[
    if (flutterRoot != null && flutterRoot.isNotEmpty)
      File(
        p.join(
          flutterRoot,
          'bin',
          'cache',
          'artifacts',
          'material_fonts',
          'MaterialIcons-Regular.otf',
        ),
      ),
    File(
      '/Users/yangyang/development/flutter/bin/cache/artifacts/'
      'material_fonts/MaterialIcons-Regular.otf',
    ),
  ];
  for (final iconFont in iconCandidates) {
    if (!await iconFont.exists()) continue;
    final bytes = await iconFont.readAsBytes();
    await (FontLoader('MaterialIcons')
          ..addFont(Future.value(ByteData.sublistView(bytes))))
        .load();
    break;
  }
}
