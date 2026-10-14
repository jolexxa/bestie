import 'package:agent_runtime/src/mapping/tool_mapper.dart';
import 'package:agent_runtime_protocol/agent_runtime_protocol.dart';
import 'package:completion_protocol/completion_protocol.dart';
import 'package:test/test.dart';

import '../../helpers.dart';

void main() {
  test('toCompletionTool keeps name, description and schema', () {
    final mapped = toCompletionTool(tool('echo'));

    expect(mapped.name, 'echo');
    expect(mapped.description, 'The echo tool');
    expect(mapped.parameters['type'], 'object');
  });

  test('toToolCall adopts the provider id', () {
    const call = CompletionToolCall(
      id: 'call_1',
      name: 'echo',
      arguments: {'text': 'hi'},
      rawArguments: '{"text":"hi"}',
    );

    final mapped = toToolCall(call, mint: () => 'minted');

    expect(mapped, isA<ToolCallDefault>());
    expect(mapped.id, 'call_1');
    expect(mapped.name, 'echo');
    expect(mapped.arguments, {'text': 'hi'});
  });

  test('toToolCall mints an id when the provider sent none', () {
    const call = CompletionToolCall(
      id: '',
      name: 'echo',
      arguments: {},
      rawArguments: '{}',
    );

    expect(toToolCall(call, mint: () => 'minted').id, 'minted');
  });
}
