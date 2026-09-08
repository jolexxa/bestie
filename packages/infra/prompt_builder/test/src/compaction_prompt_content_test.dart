import 'package:prompt_builder/prompt_builder.dart';
import 'package:test/test.dart';

void main() {
  test('carries the instruction, prefill, and format verbatim', () {
    const content = CompactionPromptContent(
      instruction: 'summarize',
      prefill: '## Goal\n',
      format: 'use this format',
    );

    expect(content.instruction, 'summarize');
    expect(content.prefill, '## Goal\n');
    expect(content.format, 'use this format');
  });
}
