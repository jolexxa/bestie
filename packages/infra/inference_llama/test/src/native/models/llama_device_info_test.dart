import 'package:inference_llama/src/native/models/models.dart';
import 'package:test/test.dart';

void main() {
  group('LlamaDeviceInfo', () {
    test('usedMemory is total minus free memory', () {
      const info = LlamaDeviceInfo(
        name: 'GPU',
        description: 'Test GPU',
        type: LlamaDeviceType.gpu,
        freeMemory: 4,
        totalMemory: 10,
      );

      expect(info.usedMemory, 6);
    });
  });
}
