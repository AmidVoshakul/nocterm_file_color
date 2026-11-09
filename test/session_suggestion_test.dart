import 'package:nocterm/nocterm.dart';
import 'package:nocterm_file_color/nocterm_file_color.dart';
import 'package:test/test.dart';

void main() {
  group('FileTextFieldSuggestion.session', () {
    test('creates session suggestion with default style', () {
      const suggestion = FileTextFieldSuggestion.session(name: 'main');
      expect(suggestion.kind, FileTextFieldSuggestionKind.session);
      expect(suggestion.name, 'main');
      expect(suggestion.style, FileTextFieldSuggestion.defaultSessionStyle);
      expect(suggestion.displayLabel, '@session main');
    });

    test('searchableText is lowercased', () {
      const suggestion = FileTextFieldSuggestion.session(
        name: 'WorkSession',
        searchText: 'work session',
      );
      expect(suggestion.searchableText, 'work session @session worksession');
    });

    test('custom style is used', () {
      const customStyle = FileStyle(
        text: Colors.brightWhite,
        background: Colors.blue,
      );
      const suggestion = FileTextFieldSuggestion.session(
        name: 's1',
        style: customStyle,
      );
      expect(suggestion.style, customStyle);
    });

    test('custom prefix overrides default', () {
      const suggestion = FileTextFieldSuggestion.session(
        name: 'main',
        prefix: '@',
      );
      expect(suggestion.displayLabel, '@main');
    });

    test('empty prefix produces plain name', () {
      const suggestion = FileTextFieldSuggestion.session(
        name: 'main',
        prefix: '',
      );
      expect(suggestion.displayLabel, 'main');
    });
  });
}
