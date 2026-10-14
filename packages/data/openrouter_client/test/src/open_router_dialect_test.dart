import 'package:completion_protocol/completion_protocol.dart';
import 'package:openrouter_client/src/open_router_dialect.dart';
import 'package:test/test.dart';

CompletionRequest _asking(CompletionReasoning reasoning) => CompletionRequest(
  model: 'm',
  messages: const [],
  reasoning: reasoning,
  agent: const AgentIdentity(id: 'primary:1', kind: AgentIdentityKind.primary),
);

void main() {
  const dialect = OpenRouterDialect();

  test('says nothing about reasoning by default', () {
    final extensions = dialect.extensionsFor(
      _asking(const CompletionReasoningDefault()),
    );

    expect(extensions.body, isEmpty);
  });

  test('toggles reasoning through the reasoning object', () {
    expect(
      dialect.extensionsFor(_asking(const CompletionReasoningEnabled())).body,
      {
        'reasoning': {'enabled': true},
      },
    );
    expect(
      dialect.extensionsFor(_asking(const CompletionReasoningDisabled())).body,
      {
        'reasoning': {'enabled': false},
      },
    );
  });

  test('asks for every effort by name through the reasoning object', () {
    for (final effort in CompletionEffort.values) {
      final extensions = dialect.extensionsFor(
        _asking(CompletionReasoningEffort(effort)),
      );

      expect(extensions.body, {
        'reasoning': {'effort': effort.name},
      });
    }
  });

  test('never names the agent or sends template switches', () {
    for (final reasoning in [
      const CompletionReasoningDefault(),
      const CompletionReasoningEnabled(),
      const CompletionReasoningDisabled(),
      const CompletionReasoningEffort(CompletionEffort.low),
    ]) {
      final extensions = dialect.extensionsFor(_asking(reasoning));

      expect(extensions.headers, isEmpty, reason: '$reasoning');
      expect(
        extensions.body.containsKey('chat_template_kwargs'),
        isFalse,
        reason: '$reasoning',
      );
      expect(
        extensions.body.containsKey('reasoning_effort'),
        isFalse,
        reason: '$reasoning',
      );
    }
  });
}
