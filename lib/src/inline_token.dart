import 'file_config.dart';

/// A colored inline token matched against rendered text.
///
/// [token] is the literal substring to find and color. [style] is applied to
/// every occurrence of [token] in the rendered text. This is a pure coloring
/// description: it carries no file attachment, editing, or menu behavior.
class InlineToken {
  /// Creates a token that colors every occurrence of [token] with [style].
  const InlineToken({required this.token, required this.style});

  /// The literal substring to find and color in the rendered text.
  final String token;

  /// Visual appearance applied to each occurrence of [token].
  final FileStyle style;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is InlineToken && other.token == token && other.style == style;
  }

  @override
  int get hashCode => Object.hash(token, style);
}
