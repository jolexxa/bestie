import 'package:completion_openai/completion_openai.dart';
import 'package:completion_protocol/completion_protocol.dart';
import 'package:test/test.dart';

CompletionRequest _asking(CompletionReasoning reasoning) => CompletionRequest(
  model: 'm',
  messages: const [],
  reasoning: reasoning,
  agent: const AgentIdentity(id: 'primary:1', kind: AgentIdentityKind.primary),
);

void main() {
  const dialect = StandardOpenAiDialect();

  test('says nothing about reasoning by default or when enabled', () {
    for (final reasoning in const [
      CompletionReasoningDefault(),
      CompletionReasoningEnabled(),
    ]) {
      final extensions = dialect.extensionsFor(_asking(reasoning));

      expect(extensions.body, isEmpty, reason: '$reasoning');
      expect(extensions.headers, isEmpty, reason: '$reasoning');
    }
  });

  test('turns reasoning off through an effort of none', () {
    final extensions = dialect.extensionsFor(
      _asking(const CompletionReasoningDisabled()),
    );

    expect(extensions.body, {'reasoning_effort': 'none'});
  });

  test('asks for every effort by name', () {
    for (final effort in CompletionEffort.values) {
      final extensions = dialect.extensionsFor(
        _asking(CompletionReasoningEffort(effort)),
      );

      expect(extensions.body, {'reasoning_effort': effort.name});
      expect(extensions.headers, isEmpty);
    }
  });

  test('never names the agent', () {
    final extensions = dialect.extensionsFor(
      _asking(const CompletionReasoningDefault()),
    );

    expect(extensions.headers, isEmpty);
  });
}
