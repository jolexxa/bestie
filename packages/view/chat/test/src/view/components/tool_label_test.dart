import 'package:agent_repository/agent_repository.dart';
import 'package:bestie_chat_view/src/view/components/tool_label.dart';
import 'package:test/test.dart';
import 'package:tool_protocol/tool_protocol.dart' show ToolCallDefault;

void main() {
  group('interpolateLabel', () {
    test('splits literals and interpolated values into styled spans', () {
      expect(
        interpolateLabel(r'Read ${path:basename}', {'path': '/a/notes.txt'}),
        const [
          LabelSpan('Read ', SpanRole.literal),
          LabelSpan('notes.txt', SpanRole.value),
        ],
      );
    });

    test('applies each modifier', () {
      expect(
        interpolateLabel(r'${q:quoted}', {'q': 'poodles'}).single,
        const LabelSpan('"poodles"', SpanRole.value),
      );
      expect(
        interpolateLabel(r'${u:host}', {'u': 'https://example.com/x'}).single,
        const LabelSpan('example.com', SpanRole.value),
      );
      expect(
        interpolateLabel(r'${s:lower}', {'s': 'LOUD'}).single,
        const LabelSpan('loud', SpanRole.value),
      );
    });

    test('falls back to the raw value when a modifier cannot apply', () {
      expect(
        interpolateLabel(r'${p:basename}', {'p': 'bare'}).single.text,
        'bare',
      );
      expect(
        interpolateLabel(r'${u:host}', {'u': 'not a url'}).single.text,
        'not a url',
      );
    });

    test('drops a missing argument and trims surrounding space', () {
      expect(interpolateLabel(r'Listing files ${path}', const {}), const [
        LabelSpan('Listing files', SpanRole.literal),
      ]);
    });

    test('stringifies non-string argument values', () {
      expect(
        interpolateLabel(r'= ${n}', {'n': 42}).last,
        const LabelSpan('42', SpanRole.value),
      );
    });

    // A stub row is one line. A heredoc or a multi-line script laid out
    // verbatim pushes the rest of the conversation off the screen.
    test('flattens a multi-line argument onto one line', () {
      expect(
        interpolateLabel(r'Ran ${command}', {
          'command': 'for i in 1 2; do\r\n  echo one\ndone\n',
        }).last,
        const LabelSpan('for i in 1 2; do echo one done', SpanRole.value),
      );
    });

    // Flattening happens first, so `truncate` counts what will be drawn
    // rather than the breaks and indentation that are about to be dropped.
    test('flattens before truncating', () {
      final span = interpolateLabel(r'${c:truncate}', {
        'c': 'a\n${'b' * 200}',
      }).single;

      expect(span.text, startsWith('a bbb'));
      expect(span.text, endsWith('…'));
    });
  });

  group('ToolActivityLabel', () {
    ToolActivityTimelineItem item({String? template}) =>
        ToolActivityTimelineItem(
          id: 't1',
          timestamp: DateTime.utc(2026),
          toolCall: const ToolCallDefault(
            id: 'tc1',
            name: 'calculator',
            arguments: {'expression': '2+2'},
          ),
          labelTemplate: template,
        );

    test('interpolates its template against the call arguments', () {
      expect(item(template: r'Calculated ${expression}').labelSpans, const [
        LabelSpan('Calculated ', SpanRole.literal),
        LabelSpan('2+2', SpanRole.value),
      ]);
    });

    test('falls back to the tool name without a template', () {
      expect(item().labelSpans, const [
        LabelSpan('calculator', SpanRole.literal),
      ]);
    });
  });

  group('JobReportLabel', () {
    test('interpolates the label stamped at delivery', () {
      const report = DeliveredJobReport(
        callId: 'call-1',
        toolName: 'subagent',
        succeeded: true,
        body: 'done',
        outstanding: 0,
        labelTemplate: r'Subagent finished: ${title}',
        labelArguments: {'title': 'Research'},
      );

      expect(report.labelSpans, const [
        LabelSpan('Subagent finished: ', SpanRole.literal),
        LabelSpan('Research', SpanRole.value),
      ]);
    });

    test('falls back to the tool name without a stamped label', () {
      const report = DeliveredJobReport(
        callId: 'call-1',
        toolName: 'shell',
        succeeded: true,
        body: 'done',
        outstanding: 0,
      );

      expect(report.labelSpans, const [LabelSpan('shell', SpanRole.literal)]);
    });
  });
}
