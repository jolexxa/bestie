import 'dart:convert';

import 'package:bestie_platform_macos/bestie_platform_macos.dart';
import 'package:mocktail/mocktail.dart';
import 'package:process_host/process_host.dart';
import 'package:test/test.dart';

class _MockProcessRunner extends Mock implements ProcessRunner {}

void main() {
  group('MacOSClipboardDataSource', () {
    late _MockProcessRunner runner;
    late MacOSClipboardDataSource dataSource;

    setUp(() {
      runner = _MockProcessRunner();
      dataSource = MacOSClipboardDataSource(runner: runner);
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

    test('copies text to pbcopy over stdin', () async {
      await dataSource.copy('hello 🐮');

      final captured = verify(
        () => runner.run(
          'pbcopy',
          arguments: any(named: 'arguments'),
          stdin: captureAny(named: 'stdin'),
        ),
      ).captured.single;
      expect(utf8.decode(captured as List<int>), 'hello 🐮');
    });
  });
}
