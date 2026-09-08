import 'package:agent_provider_protocol/agent_provider_protocol.dart';
import 'package:agent_provider_remote/src/mapping/tool_mapper.dart';
import 'package:inference_protocol/inference_protocol.dart';
import 'package:test/test.dart';

import '../../helpers.dart';

void main() {
  test('toInferenceTool keeps name, description and schema', () {
    final mapped = toInferenceTool(tool('echo'));

    expect(mapped.name, 'echo');
    expect(mapped.description, 'The echo tool');
    expect(mapped.parameters['type'], 'object');
  });

  test('toToolCall adopts the provider id', () {
    const call = InferenceToolCall(
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
    const call = InferenceToolCall(
      id: '',
      name: 'echo',
      arguments: {},
      rawArguments: '{}',
    );

    expect(toToolCall(call, mint: () => 'minted').id, 'minted');
  });
}
