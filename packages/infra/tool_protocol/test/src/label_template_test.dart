import 'package:test/test.dart';
import 'package:tool_protocol/tool_protocol.dart';

void main() {
  test('reads every substituted argument name, with or without a modifier', () {
    expect(
      labelArgumentKeys(r'Read ${path:basename} for ${reason}'),
      {'path', 'reason'},
    );
  });

  test('a template that substitutes nothing needs no arguments', () {
    expect(labelArgumentKeys('Done'), isEmpty);
  });

  test('keeps only the arguments its template substitutes', () {
    expect(
      labelArgumentsFor(r'Subagent finished: ${title}', {
        'title': 'Web Search',
        'prompt': 'a very long prompt that should not be duplicated',
      }),
      {'title': 'Web Search'},
    );
  });

  test('drops every argument when the template is empty', () {
    expect(labelArgumentsFor('', {'title': 'Web Search'}), isEmpty);
  });
}
