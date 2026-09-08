import 'package:test/test.dart';
import 'package:tool_protocol/tool_protocol.dart';

const int _ceiling = 4000;

int budget(int availableTokens, {int ceiling = _ceiling}) => maxOutputCharsFor(
  availableTokens: availableTokens,
  maxToolCallCharacters: ceiling,
);

void main() {
  group('maxOutputCharsFor', () {
    test('spends the characters that free tokens hold', () {
      expect(budget(300), 1200);
      expect(budget(600), 2400);
    });

    test('never exceeds the configured ceiling', () {
      expect(budget(24000), _ceiling);
      expect(budget(108000), _ceiling);
    });

    test('honours a ceiling the operator lowered', () {
      expect(budget(108000, ceiling: 800), 800);
      expect(budget(100, ceiling: 800), 400);
    });

    test('honours a ceiling the operator raised', () {
      expect(budget(108000, ceiling: 32000), 32000);
      expect(budget(4000, ceiling: 32000), 16000);
    });

    test('takes the ceiling exactly where free context reaches it', () {
      expect(budget(_ceiling ~/ 4), _ceiling);
      expect(budget(_ceiling ~/ 4 - 1), _ceiling - 4);
    });

    test('reports no room rather than a minimum when context is gone', () {
      expect(budget(0), 0);
    });

    test('stays negative when the context is already overdrawn', () {
      expect(budget(-400).isNegative, isTrue);
    });
  });

  group('roomUnderMessage', () {
    test('charges for the message and the line under it', () {
      expect(
        roomUnderMessage('Exited with code 1.', maxChars: 100),
        100 - 'Exited with code 1.'.length - messageSeparator.length,
      );
    });

    test('holds content and message together inside the allowance', () {
      const message = 'Killed by signal 9.';
      final content = 'x' * roomUnderMessage(message, maxChars: 60);
      final failed = ToolCallFailed(
        callId: 'call-1',
        toolName: 'bash',
        message: message,
        content: content,
      );

      expect(failed.modelText.length, 60);
    });
  });
}
