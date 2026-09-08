import 'package:agent_repository/agent_repository.dart'
    show DeliveredJobReport, JobInBackground, ToolActivityTimelineItem;
import 'package:bestie_ui/bestie_ui.dart' show TruncateFormatting;
import 'package:characters/characters.dart';
import 'package:intentions/intentions.dart';
import 'package:meta/meta.dart';
import 'package:nocterm/nocterm.dart' show UnicodeWidth;
import 'package:tool_protocol/tool_protocol.dart' show labelPlaceholder;

/// Whether a label span is fixed template text or an interpolated argument.
/// The view colors [literal] by call status and dims [value].
enum SpanRole { literal, value }

/// A styled fragment of a rendered tool-activity label.
@model
@immutable
class LabelSpan {
  const LabelSpan(this.text, this.role);

  final String text;
  final SpanRole role;

  @override
  bool operator ==(Object other) =>
      other is LabelSpan && other.text == text && other.role == role;

  @override
  int get hashCode => Object.hash(text, role);

  @override
  String toString() => 'LabelSpan("$text", $role)';
}

/// Interpolates a denormalized label [template] against a tool call's [args],
/// yielding styled spans. Literal text becomes [SpanRole.literal] spans; each
/// `${arg}` / `${arg:modifier}` substitution becomes a [SpanRole.value] span.
/// Missing args drop out and surrounding whitespace is trimmed, so an absent
/// optional argument leaves a clean label.
///
/// Modifiers: `basename`, `host`, `quoted`, `truncate`, `lower`.
List<LabelSpan> interpolateLabel(String template, Map<String, Object?> args) {
  final spans = <LabelSpan>[];
  var cursor = 0;
  for (final match in labelPlaceholder.allMatches(template)) {
    if (match.start > cursor) {
      spans.add(
        LabelSpan(template.substring(cursor, match.start), SpanRole.literal),
      );
    }
    final value = _resolve(args[match.group(1)], match.group(2));
    if (value.isNotEmpty) spans.add(LabelSpan(value, SpanRole.value));
    cursor = match.end;
  }
  if (cursor < template.length) {
    spans.add(LabelSpan(template.substring(cursor), SpanRole.literal));
  }
  return _trimEnds(spans);
}

/// A line break and whatever whitespace is padding it.
final _lineBreak = RegExp(r'\s*[\r\n]+\s*');

/// Flattens an argument to one line.
///
/// A stub row is an index entry, and a heredoc or a multi-line script arrives
/// here carrying its own breaks and indentation — laid out verbatim, one call
/// pushes the rest of the conversation off the screen.
String _oneLine(String value) => value.replaceAll(_lineBreak, ' ').trim();

/// Marks a label the row was too narrow to finish.
const String labelEllipsis = '…';

/// The leading [spans] that fit across [columns] terminal cells, with the one
/// that runs out cut short and marked with [labelEllipsis].
///
/// Measured and cut here rather than left to the text layout, which breaks on
/// a word boundary before it truncates: a label whose argument is one long
/// token — a command, a URL — would lose the whole argument instead of its
/// tail, which is the part a reader is least likely to need.
List<LabelSpan> fitLabel(List<LabelSpan> spans, int columns) {
  final fitted = <LabelSpan>[];
  var left = columns;
  for (final span in spans) {
    if (left <= 0) break;
    final width = UnicodeWidth.stringWidth(span.text);
    if (width <= left) {
      fitted.add(span);
      left -= width;
      continue;
    }
    fitted.add(LabelSpan(_cut(span.text, left), span.role));
    break;
  }
  return fitted;
}

/// [text] cut to the last grapheme that leaves room for the ellipsis.
String _cut(String text, int columns) {
  final room = columns - UnicodeWidth.stringWidth(labelEllipsis);
  final head = StringBuffer();
  var used = 0;
  for (final grapheme in text.characters) {
    final width = UnicodeWidth.graphemeWidth(grapheme);
    if (used + width > room) break;
    head.write(grapheme);
    used += width;
  }
  return '$head$labelEllipsis';
}

String _resolve(Object? raw, String? modifier) {
  if (raw == null) return '';
  final value = _oneLine('$raw');
  switch (modifier) {
    case 'basename':
      final parts = value.split(RegExp(r'[/\\]')).where((s) => s.isNotEmpty);
      return parts.isEmpty ? value : parts.last;
    case 'host':
      final host = Uri.tryParse(value)?.host ?? '';
      return host.isEmpty ? value : host;
    case 'quoted':
      return '"$value"';
    case 'truncate':
      return value.truncate();
    case 'lower':
      return value.toLowerCase();
    default:
      return value;
  }
}

/// The label spans a tool-call row renders.
extension ToolActivityLabel on ToolActivityTimelineItem {
  List<LabelSpan> get labelSpans {
    final template = labelTemplate;
    if (template == null || template.isEmpty) {
      return [LabelSpan(toolCall.name, SpanRole.literal)];
    }
    return interpolateLabel(template, toolCall.arguments);
  }
}

/// The label spans a settled-job report row renders, from the label stamped
/// on it at delivery.
extension JobReportLabel on DeliveredJobReport {
  List<LabelSpan> get labelSpans => labelTemplate.isEmpty
      ? [LabelSpan(toolName, SpanRole.literal)]
      : interpolateLabel(labelTemplate, labelArguments);
}

/// The label spans a running-job row renders, from the label stamped on it
/// when its call was handed back.
extension JobInBackgroundLabel on JobInBackground {
  List<LabelSpan> get labelSpans => labelTemplate.isEmpty
      ? [LabelSpan(toolName, SpanRole.literal)]
      : interpolateLabel(labelTemplate, labelArguments);
}

List<LabelSpan> _trimEnds(List<LabelSpan> spans) {
  if (spans.isEmpty) return spans;
  spans[0] = LabelSpan(spans.first.text.trimLeft(), spans.first.role);
  final last = spans.length - 1;
  spans[last] = LabelSpan(spans[last].text.trimRight(), spans[last].role);
  return spans.where((s) => s.text.isNotEmpty).toList();
}
