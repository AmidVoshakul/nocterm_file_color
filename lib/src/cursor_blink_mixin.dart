import 'dart:async';

import 'package:nocterm/nocterm.dart';

/// Mixin for components that emulate block/underline cursor blinking over a
/// transparent [TextField] + [RichText] overlay.
///
/// Provides cursor visibility state and a timer that toggles it according to
/// `cursorBlinkRate`.
mixin CursorBlinkMixin<T extends StatefulComponent> on State<T> {
  Timer? _cursorBlinkTimer;
  bool _cursorBlinkActive = false;
  Duration? _cursorBlinkRate;
  bool _cursorVisible = true;

  /// Called when the set of visible tokens or focus changes.
  void syncCursorBlink({
    required bool hasTokens,
    required bool obscureText,
    required bool focused,
    required bool showCursor,
    Duration? cursorBlinkRate,
  }) {
    final want = hasTokens && !obscureText && focused && showCursor;
    if (want == _cursorBlinkActive && cursorBlinkRate == _cursorBlinkRate) {
      return;
    }

    _cursorBlinkActive = want;
    _cursorBlinkRate = cursorBlinkRate;
    _cursorBlinkTimer?.cancel();
    _cursorBlinkTimer = null;

    if (want) {
      _cursorVisible = true;
      if (cursorBlinkRate != null) {
        _cursorBlinkTimer = Timer.periodic(cursorBlinkRate, (_) {
          if (mounted) setState(() => _cursorVisible = !_cursorVisible);
        });
      }
    } else {
      _cursorVisible = false;
    }
  }

  bool get cursorVisible => _cursorVisible;

  @override
  void dispose() {
    _cursorBlinkTimer?.cancel();
    super.dispose();
  }
}
