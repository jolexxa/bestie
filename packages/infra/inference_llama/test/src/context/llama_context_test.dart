import 'package:inference/inference.dart';
import 'package:inference_llama/src/context/llama_context.dart';
import 'package:inference_llama/src/context/llama_context_engine.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../fixtures/mocks.dart';

void main() {
  group('LlamaContext', () {
    test('dispose frees the context once and is idempotent', () async {
      final client = stubbedLlamaClient();
      final context = _context(client);

      final first = await context.dispose();
      final second = await context.dispose();

      expect(first, isA<DisposeContextSucceeded>());
      expect(second, isA<DisposeContextSucceeded>());
      verify(() => client.disposeContext(fakeContextHandle)).called(1);
    });
  });
}

LlamaContext _context(MockLlamaClientApi client) {
  final envelope = fakeEnvelope(maxSequences: 2, maxBatchTokens: 16);
  return LlamaContext(
    engine: LlamaContextEngine(
      client: client,
      model: fakeModelHandle,
      context: fakeContextHandle,
      envelope: envelope,
    ),
    envelope: envelope,
  );
}
