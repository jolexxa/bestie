// Replays a long markdown document token by token through a full parse and
// through the incremental parser, and reports the time per update of each.
//
//   dart run benchmark/incremental_parse.dart
import 'dart:io';
import 'dart:math';

import 'package:markdown_highlighted/markdown_highlighted.dart';
import 'package:markdown_highlighted/src/internal/incremental_markdown_parser.dart';
import 'package:markdown_highlighted/src/internal/markdown_document.dart';
import 'package:markdown_highlighted/src/markdown_visitor.dart';

import '../test/src/support/markdown_generator.dart';

const int _targetLength = 200 * 1024;
const int _chunkLength = 4;
const int _fullParseSamples = 40;

void main() {
  final random = Random(7);
  final buffer = StringBuffer();
  while (buffer.length < _targetLength) {
    buffer
      ..write(generateMarkdown(random, blockCount: 20))
      ..write('\n\n');
  }
  buffer.write(_giantList(400));
  final source = buffer.toString();
  final visitor = MarkdownVisitor(
    theme: MarkdownTheme.terminal(),
    builders: MarkdownBuilders.defaults(),
    maxWidth: 100,
    streaming: true,
  );

  final incremental = <int>[];
  final full = <int>[];
  final parser = IncrementalMarkdownParser();
  final stopwatch = Stopwatch();
  final steps = source.length ~/ _chunkLength;
  final fullEvery = max(1, steps ~/ _fullParseSamples);
  for (var step = 1; step <= steps; step++) {
    final partial = source.substring(
      0,
      min(source.length, step * _chunkLength),
    );

    stopwatch
      ..reset()
      ..start();
    final parse = parser.update(partial);
    parse.nodes.skip(parse.stableCount).forEach(visitor.blocksFor);
    stopwatch.stop();
    incremental.add(stopwatch.elapsedMicroseconds);

    if (step % fullEvery == 0) {
      stopwatch
        ..reset()
        ..start();
      visitor.visit(buildMarkdownDocument().parse(partial));
      stopwatch.stop();
      full.add(stopwatch.elapsedMicroseconds);
    }
  }

  stdout
    ..writeln(
      'source: ${source.length} chars, $steps updates of '
      '$_chunkLength chars',
    )
    ..writeln('incremental: ${_report(incremental)}')
    ..writeln('full parse:  ${_report(full)} (${full.length} samples)');
}

String _giantList(int items) => [
  for (var index = 0; index < items; index++)
    '- item $index with **bold** and `code` and a [link](https://x/$index)',
].join('\n');

String _report(List<int> micros) {
  final sorted = [...micros]..sort();
  String at(double quantile) {
    final value =
        sorted[min(sorted.length - 1, (sorted.length * quantile).floor())];
    return '${(value / 1000).toStringAsFixed(3)} ms';
  }

  return 'p50 ${at(0.5)}, p95 ${at(0.95)}, max ${at(1)}';
}
