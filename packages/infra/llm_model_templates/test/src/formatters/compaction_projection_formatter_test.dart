import 'package:llm_model_templates/llm_model_templates.dart';
import 'package:test/test.dart';

/// Locks how each prompt formatter renders the compaction projection
/// `[system, <memory>, …tail]` for both possible synthetic-memory
/// roles (`assistant` when tail starts with user, `user` when tail
/// starts with assistant). The formatters themselves are unchanged
/// from before compaction landed; this regression suite ensures we
/// notice if a future formatter edit breaks the projection.
void main() {
  const sys = PromptSystemMessage('You are helpful.');
  const memoryText =
      'Earlier: user asked about scheduling; '
      'assistant suggested calendar.';

  PromptMessage memoryAsAssistant() =>
      const PromptAssistantMessage(content: memoryText);

  PromptMessage memoryAsUser() => const PromptUserMessage(memoryText);

  group('Qwen3 compaction projection', () {
    const formatter = Qwen3PromptFormatter();

    test('memory-as-assistant when tail starts with user', () {
      final prompt = formatter.format(
        messages: [
          sys,
          memoryAsAssistant(),
          const PromptUserMessage('now help me'),
        ],
        tools: const [],
        reasoningMode: 'on',
      );

      expect(prompt, contains('<|im_start|>system\nYou are helpful.'));
      expect(prompt, contains('<|im_start|>assistant\n$memoryText'));
      expect(prompt, contains('<|im_start|>user\nnow help me'));
      // Generation prompt ends the prompt.
      expect(prompt.trimRight(), endsWith('<|im_start|>assistant'));
    });

    test('memory-as-user when tail starts with assistant', () {
      final prompt = formatter.format(
        messages: [
          sys,
          memoryAsUser(),
          const PromptAssistantMessage(content: 'continuing where we left off'),
          const PromptUserMessage('next question'),
        ],
        tools: const [],
        reasoningMode: 'on',
      );

      expect(prompt, contains('<|im_start|>system\nYou are helpful.'));
      expect(prompt, contains('<|im_start|>user\n$memoryText'));
      expect(
        prompt,
        contains('<|im_start|>assistant\ncontinuing where we left off'),
      );
      expect(prompt.trimRight(), endsWith('<|im_start|>assistant'));
    });
  });

  group('Qwen2.5 compaction projection', () {
    const formatter = Qwen25PromptFormatter();

    test('memory-as-assistant when tail starts with user', () {
      final prompt = formatter.format(
        messages: [
          sys,
          memoryAsAssistant(),
          const PromptUserMessage('now help me'),
        ],
        tools: const [],
        reasoningMode: 'on',
      );

      expect(prompt, contains('<|im_start|>system'));
      expect(prompt, contains('You are helpful.'));
      expect(prompt, contains('<|im_start|>assistant'));
      expect(prompt, contains(memoryText));
      expect(prompt, contains('<|im_start|>user'));
      expect(prompt, contains('now help me'));
    });

    test('memory-as-user when tail starts with assistant', () {
      final prompt = formatter.format(
        messages: [
          sys,
          memoryAsUser(),
          const PromptAssistantMessage(content: 'continuing'),
        ],
        tools: const [],
        reasoningMode: 'on',
      );

      expect(prompt, contains('<|im_start|>system'));
      expect(prompt, contains(memoryText));
      expect(prompt, contains('<|im_start|>user'));
      expect(prompt, contains('continuing'));
    });
  });

  group('Gemma4 compaction projection', () {
    const formatter = Gemma4PromptFormatter();

    test('memory-as-assistant maps to model turn before user tail', () {
      final prompt = formatter.format(
        messages: [
          sys,
          memoryAsAssistant(),
          const PromptUserMessage('hi'),
        ],
        tools: const [],
        reasoningMode: 'off',
      );

      expect(prompt, contains('<|turn>system\n'));
      expect(prompt, contains('You are helpful.'));
      // Assistant maps to "model" in gemma4.
      expect(prompt, contains('<|turn>model\n$memoryText'));
      expect(prompt, contains('<|turn>user\nhi'));
    });

    test('memory-as-user renders as plain user turn', () {
      final prompt = formatter.format(
        messages: [
          sys,
          memoryAsUser(),
          const PromptAssistantMessage(content: 'ok'),
        ],
        tools: const [],
        reasoningMode: 'off',
      );

      expect(prompt, contains('<|turn>user\n$memoryText'));
      expect(prompt, contains('<|turn>model\nok'));
    });
  });

  group('Harmony compaction projection', () {
    const formatter = HarmonyPromptFormatter();

    test('memory-as-assistant lands in the final channel', () {
      final prompt = formatter.format(
        messages: [
          sys,
          memoryAsAssistant(),
          const PromptUserMessage('next'),
        ],
        tools: const [],
        reasoningMode: 'medium',
      );

      // System + developer blocks plus the synthetic memory rendered as
      // an assistant final-channel message.
      expect(prompt, contains('<|start|>system'));
      expect(prompt, contains('<|start|>developer'));
      expect(prompt, contains('You are helpful.'));
      expect(
        prompt,
        contains(
          '<|start|>assistant<|channel|>final<|message|>$memoryText<|end|>',
        ),
      );
      expect(prompt, contains('<|start|>user<|message|>next<|end|>'));
    });

    test('memory-as-user renders as a normal user message', () {
      final prompt = formatter.format(
        messages: [
          sys,
          memoryAsUser(),
          const PromptAssistantMessage(content: 'continuing'),
        ],
        tools: const [],
        reasoningMode: 'medium',
      );

      expect(prompt, contains('<|start|>user<|message|>$memoryText<|end|>'));
      expect(
        prompt,
        contains('<|start|>assistant<|channel|>final<|message|>continuing'),
      );
    });
  });
}
