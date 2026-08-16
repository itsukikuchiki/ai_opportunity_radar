import 'package:flutter/material.dart';

import '../../core/i18n/app_locale_text.dart';

/// Gives every route a consistent way to dismiss the software keyboard.
///
/// Taps inside the currently focused editor are left alone so cursor movement
/// and text selection keep working. Taps elsewhere clear focus, and an
/// explicit button remains available for multiline editors where the return
/// key must continue to insert a newline.
class KeyboardDismissScope extends StatelessWidget {
  final Widget child;

  const KeyboardDismissScope({
    super.key,
    required this.child,
  });

  void _dismissWhenOutside(PointerDownEvent event) {
    final focus = FocusManager.instance.primaryFocus;
    final focusedContext = focus?.context;
    if (focus == null || focusedContext == null) return;

    final renderObject = focusedContext.findRenderObject();
    if (renderObject is RenderBox && renderObject.attached) {
      final bounds =
          renderObject.localToGlobal(Offset.zero) & renderObject.size;
      if (bounds.contains(event.position)) return;
    }

    focus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final keyboardVisible = keyboardInset > 0;
    final tooltip = AppLocaleText.tr(
      context,
      en: 'Hide keyboard',
      zhHans: '收起键盘',
      zhHant: '收起鍵盤',
      ja: 'キーボードを閉じる',
    );

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _dismissWhenOutside,
      child: Stack(
        children: [
          child,
          if (keyboardVisible)
            PositionedDirectional(
              key: const ValueKey('global-keyboard-dismiss-control'),
              end: 12,
              bottom: keyboardInset + 8,
              child: SafeArea(
                top: false,
                bottom: false,
                child: Material(
                  color: Theme.of(context).colorScheme.surface,
                  elevation: 4,
                  shadowColor: Colors.black26,
                  shape: const CircleBorder(),
                  child: IconButton(
                    key: const ValueKey('global-keyboard-dismiss-button'),
                    onPressed: () =>
                        FocusManager.instance.primaryFocus?.unfocus(),
                    tooltip: tooltip,
                    icon: const Icon(Icons.keyboard_hide_rounded),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
