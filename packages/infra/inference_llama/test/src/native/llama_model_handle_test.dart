import 'dart:ffi';

import 'package:inference_llama/src/native/native.dart';
import 'package:test/test.dart';

import '../../fixtures/fake_bindings.dart';

void main() {
  group('LlamaModelHandle', () {
    test('client reconstructs from model pointer', () {
      final bindings = FakeLlamaCppBindings();
      final client = LlamaClient(bindings: bindings);

      final model = client.modelHandleFromPointer(42);

      expect(model.pointer.address, 42);
      expect(model.vocab, isNot(nullptr));
      expect(model.pointerAddress, 42);
    });
  });
}
