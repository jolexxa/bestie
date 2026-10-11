import 'package:completion_protocol/completion_protocol.dart';
import 'package:local_server_protocol/local_server_protocol.dart';
import 'package:provider_local/src/bestie_server_dialect.dart';
import 'package:test/test.dart';

const _primary = AgentIdentity(
  id: 'primary:1',
  kind: AgentIdentityKind.primary,
);

CompletionRequest _asking(
  CompletionReasoning reasoning, {
  AgentIdentity? agent = _primary,
}) => CompletionRequest(
  model: 'm',
  messages: const [],
  reasoning: reasoning,
  agent: agent,
);

void main() {
  const dialect = BestieServerDialect();

  test('names the agent on every completion', () {
    for (final reasoning in [
      const CompletionReasoningDefault(),
      const CompletionReasoningEnabled(),
      const CompletionReasoningDisabled(),
      const CompletionReasoningEffort(CompletionEffort.low),
    ]) {
      expect(
        dialect.extensionsFor(_asking(reasoning)).headers,
        {bestieAgentHeader: 'primary:1'},
        reason: '$reasoning',
      );
    }
  });

  test('sends no agent header for an anonymous completion', () {
    final extensions = dialect.extensionsFor(
      _asking(const CompletionReasoningDefault(), agent: null),
    );

    expect(extensions.headers, isEmpty);
  });

  test('toggles thinking through the chat template', () {
    expect(
      dialect.extensionsFor(_asking(const CompletionReasoningEnabled())).body,
      {
        bestieChatTemplateKwargsField: {bestieEnableThinkingKey: true},
      },
    );
    expect(
      dialect.extensionsFor(_asking(const CompletionReasoningDisabled())).body,
      {
        bestieChatTemplateKwargsField: {bestieEnableThinkingKey: false},
      },
    );
  });

  test('asks for every effort by name through reasoning_effort', () {
    for (final effort in CompletionEffort.values) {
      final extensions = dialect.extensionsFor(
        _asking(CompletionReasoningEffort(effort)),
      );

      expect(extensions.body, {'reasoning_effort': effort.name});
    }
  });

  test('says nothing about reasoning by default', () {
    final extensions = dialect.extensionsFor(
      _asking(const CompletionReasoningDefault()),
    );

    expect(extensions.body, isEmpty);
  });
}
