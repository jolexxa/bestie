import 'package:llm_model_templates/src/utils/string_extensions.dart';
import 'package:test/test.dart';

void main() {
  group('StringTrimming', () {
    test('strips leading newline characters', () {
      expect('\n\rvalue'.stripLeadingNewlines(), 'value');
    });

    test('strips trailing newline characters', () {
      expect('\nvalue\r\n'.stripEdgeNewlines(), 'value');
    });

    test('returns original string when no newline stripping is needed', () {
      expect('value'.stripLeadingNewlines(), 'value');
      expect('value'.stripEdgeNewlines(), 'value');
    });
  });
}
