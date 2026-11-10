import 'dart:io';

import 'package:nocterm/nocterm.dart';

/// Terminal colour handling shared by the package.
///
/// Nocterm downgrades true colour to ANSI-256 automatically; what it does not
/// do is honor `NO_COLOR` (https://no-color.org), so the package checks it
/// here and stops emitting colours of its own when the environment asks.
abstract final class TerminalColors {
  /// Whether the environment asked for no colour: `NO_COLOR` is present and
  /// not an empty string. Overridden with [setNoColorOverride].
  static bool get noColorEnabled =>
      _override ?? enabledIn(Platform.environment);

  /// Reads `NO_COLOR` out of [environment]. Any non-empty value counts —
  /// including `0`, which is a non-empty string.
  static bool enabledIn(Map<String, String> environment) {
    final value = environment['NO_COLOR'];
    return value != null && value.isNotEmpty;
  }

  /// [color], or `null` when colours are disabled. `null` is Nocterm's "use
  /// the terminal default", which is exactly what `NO_COLOR` asks for.
  static Color? resolve(Color? color) => noColorEnabled ? null : color;

  /// Overrides the environment probe, for tests and for hosts that read their
  /// own configuration. `null` restores the environment.
  static void setNoColorOverride(bool? value) => _override = value;

  static bool? _override;
}
