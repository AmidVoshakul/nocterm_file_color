import 'file_config.dart';

/// A colored inline token matched against rendered text.
///
/// [token] is the literal substring to find and color. Each entry colors
/// exactly one occurrence of [token]: the leftmost occurrence in the rendered
/// text that is not yet colored. Register one entry per colored label — for
/// example, one per inserted mention, command, or attachment. This is a pure
/// coloring description: it carries no file attachment, editing, or menu
/// behavior.
class InlineToken {
  /// Creates a token whose [style] colors one occurrence of [token].
  const InlineToken({required this.token, required this.style});

  /// The literal substring to find and color in the rendered text.
  final String token;

  /// Visual appearance applied to the occurrence colored by this entry.
  final FileStyle style;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is InlineToken && other.token == token && other.style == style;
  }

  @override
  int get hashCode => Object.hash(token, style);
}
