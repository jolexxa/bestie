import 'dart:math';

/// Which cross-block features a generated document may use.
final class MarkdownFeatures {
  const MarkdownFeatures({
    this.linkReferences = false,
    this.footnotes = false,
    this.htmlBlocks = false,
  });

  /// Everything the incremental parser can handle without falling back.
  static const MarkdownFeatures incremental = MarkdownFeatures();

  final bool linkReferences;
  final bool footnotes;
  final bool htmlBlocks;
}

/// Builds a markdown document from [random] that mixes every block the
/// grammar knows: paragraphs with inline styling and math, tight, loose and
/// nested lists, fences with blank lines, display math, tables, blockquotes
/// with nested fences, both heading styles, rules, and the orphaned indented
/// outlines that models stream.
String generateMarkdown(
  Random random, {
  int blockCount = 12,
  MarkdownFeatures features = MarkdownFeatures.incremental,
}) {
  final generator = _Generator(random, features);
  final blocks = [
    for (var index = 0; index < blockCount; index++) generator.block(),
  ];
  final buffer = StringBuffer();
  if (random.nextInt(4) == 0) buffer.write('\n\n');
  for (final (index, block) in blocks.indexed) {
    if (index > 0) buffer.write(random.nextInt(8) == 0 ? '\n' : '\n\n');
    buffer.write(block);
  }
  if (random.nextBool()) buffer.write('\n');
  return buffer.toString();
}

final class _Generator {
  _Generator(this.random, this.features);

  final Random random;
  final MarkdownFeatures features;

  static const _words = [
    'weaver',
    'starlight',
    'cozy',
    'ember',
    'lullaby',
    'forest',
    'shimmer',
    'whisper',
    'tea',
    'twilight',
    'dragon',
    'constellation',
  ];

  T _pick<T>(List<T> options) => options[random.nextInt(options.length)];

  String word() => _pick(_words);

  String inline() {
    final text = word();
    return switch (random.nextInt(12)) {
      0 => '**$text**',
      1 => '*$text*',
      2 => '`$text`',
      3 => '[$text](https://example.com/$text)',
      4 =>
        r'\(x_'
            '$text'
            r'\)',
      5 => '~~$text~~',
      6 when features.linkReferences => '[$text][ref]',
      7 when features.footnotes => '$text[^note]',
      _ => text,
    };
  }

  String sentence() {
    final count = 3 + random.nextInt(8);
    final words = [for (var index = 0; index < count; index++) inline()];
    return '${words.join(' ')}.';
  }

  String paragraph() {
    final count = 1 + random.nextInt(3);
    final sentences = [for (var index = 0; index < count; index++) sentence()];
    return sentences.join(random.nextBool() ? ' ' : '\n');
  }

  String block() => switch (random.nextInt(16)) {
    0 => '# ${sentence()}',
    1 => '${sentence()}\n${random.nextBool() ? '===' : '---'}',
    2 => list(tight: true),
    3 => list(tight: false),
    4 => nestedList(),
    5 => orderedList(),
    6 => fence(),
    7 => mathBlock(),
    8 => table(),
    9 => blockquote(),
    10 => '---',
    11 => orphanedOutline(),
    12 when features.htmlBlocks => '<div>\n${sentence()}\n</div>',
    13 when features.linkReferences => '[ref]: https://example.com/ref',
    14 when features.footnotes => '[^note]: ${sentence()}',
    _ => paragraph(),
  };

  String list({required bool tight}) {
    final count = 2 + random.nextInt(4);
    final items = [
      for (var index = 0; index < count; index++) '- ${sentence()}',
    ];
    return items.join(tight ? '\n' : '\n\n');
  }

  String nestedList() =>
      '- ${sentence()}\n'
      '  - ${sentence()}\n'
      '    - ${sentence()}\n'
      '- ${sentence()}';

  String orderedList() {
    final count = 2 + random.nextInt(3);
    final items = [
      for (var index = 0; index < count; index++) '${index + 1}. ${sentence()}',
    ];
    return items.join('\n');
  }

  String fence() {
    final language = _pick(['dart', 'python', '', 'json']);
    return '```$language\nfinal ${word()} = 1;\n\nprint(${word()});\n```';
  }

  String mathBlock() =>
      r'$$'
      '\n\\frac{${word()}}{${word()}} = 1\n'
      r'$$';

  String table() =>
      '| ${word()} | ${word()} |\n|---|---|\n| ${inline()} | ${word()} |';

  String blockquote() => random.nextBool()
      ? '> ${sentence()}\n>\n> ${sentence()}'
      : '> ${sentence()}\n>\n> ```\n> ${word()}\n> ```';

  String orphanedOutline() =>
      '    *   *${word()}:* ${sentence()}\n'
      '    *   ${sentence()}\n'
      '        *   ${sentence()}\n'
      '\n'
      '    *${word()}:* ${sentence()}';
}
