import 'dart:convert';

import 'package:bestie_platform_linux/bestie_platform_linux.dart';
import 'package:mocktail/mocktail.dart';
import 'package:platform/platform.dart';
import 'package:process_host/process_host.dart';
import 'package:test/test.dart';

class _MockProcessRunner extends Mock implements ProcessRunner {}

LinuxClipboardDataSource _dataSource(
  ProcessRunner runner,
  Map<String, String> environment,
) => LinuxClipboardDataSource(
  platform: FakePlatform(operatingSystem: 'linux', environment: environment),
  runner: runner,
);

void main() {
  group('LinuxClipboardDataSource', () {
    late _MockProcessRunner runner;

    setUp(() {
      runner = _MockProcessRunner();
      when(
        () => runner.run(
          any(),
          arguments: any(named: 'arguments'),
          stdin: any(named: 'stdin'),
        ),
      ).thenAnswer(
        (_) async => const ProcessRunCompleted(ProcessExited(0)),
      );
    });

    test('uses wl-copy under Wayland', () async {
      final dataSource = _dataSource(runner, const {
        'WAYLAND_DISPLAY': 'wayland-0',
      });

      await dataSource.copy('text');

      final captured = verify(
        () => runner.run(
          'wl-copy',
          arguments: any(named: 'arguments'),
          stdin: captureAny(named: 'stdin'),
        ),
      ).captured.single;
      expect(utf8.decode(captured as List<int>), 'text');
    });

    test('uses xclip on the clipboard selection under X11', () async {
      final dataSource = _dataSource(runner, const {});

      await dataSource.copy('text');

      final captured = verify(
        () => runner.run(
          'xclip',
          arguments: captureAny(named: 'arguments'),
          stdin: any(named: 'stdin'),
        ),
      ).captured.single;
      expect(captured, ['-selection', 'clipboard']);
    });
  });
}
