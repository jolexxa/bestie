import 'package:process_host_windows/process_host_windows.dart';
import 'package:test/test.dart';

class _Sandbox implements WindowsSandbox {
  @override
  String get containerSid => 'S-1-15-2-1';

  @override
  List<String> get capabilitySids => const [];

  @override
  String get workingDirectory => r'C:\work';

  @override
  String get tempDir => r'C:\Users\cow\AppData\Local\Packages\bestie\AC\Temp';
}

void main() {
  group('the environment a confined child runs in', () {
    final sandbox = _Sandbox();

    test('points TEMP and TMP at the container temp, keeping the rest', () {
      final result = sandbox.environmentFor(const {
        'PATH': r'C:\cow\bin',
        'TEMP': r'C:\Users\cow\AppData\Local\Temp',
        'TMP': r'C:\Users\cow\AppData\Local\Temp',
      });

      expect(result, {
        'PATH': r'C:\cow\bin',
        'TEMP': sandbox.tempDir,
        'TMP': sandbox.tempDir,
      });
    });

    test("drops the host's own spelling rather than racing it", () {
      // Windows reads environment names case-insensitively, so a surviving
      // `Temp` would compete with ours for the same variable.
      final result = sandbox.environmentFor(const {'Temp': r'C:\t', 'tmp': ''});

      expect(result, {'TEMP': sandbox.tempDir, 'TMP': sandbox.tempDir});
    });

    test('sets both even when the host named neither', () {
      expect(sandbox.environmentFor(const {}), {
        'TEMP': sandbox.tempDir,
        'TMP': sandbox.tempDir,
      });
    });
  });
}
