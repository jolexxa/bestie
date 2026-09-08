@TestOn('windows')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:process_host/process_host.dart';
import 'package:process_host_windows/process_host_windows.dart';
import 'package:test/test.dart';
import 'package:win32_dart/test_support.dart';

/// Real ConPTY spawns on the host, driving `cmd.exe` so the suite needs
/// nothing installed.
///
/// ConPTY emits a re-rendered screen buffer, not the child's raw bytes, so
/// assertions lean on exit codes and markers a fast command leaves on screen
/// rather than on exact output.
void main() {
  final cmd = Platform.environment['ComSpec'] ?? r'C:\Windows\System32\cmd.exe';

  late WindowsProcessHost host;

  setUp(() async {
    final conpty = await const RepoConsoleHostLocator().locate();
    if (conpty == null) {
      fail(
        'Console host not installed. Run '
        '`dart tool/download_openconsole_assets.dart` from the repo root.',
      );
    }
    host = WindowsProcessHost(conptyLibraryPath: conpty);
  });

  /// Unwraps a spawn and guarantees teardown even if the test fails — a
  /// leaked read isolate blocked in `ReadFile` would otherwise wedge VM
  /// shutdown.
  RunningProcess spawn(ProcessSpawnResult result) {
    final process = switch (result) {
      ProcessSpawnSucceeded(:final process) => process,
      ProcessSpawnFailed(:final failure) => fail('spawn failed: $failure'),
    };
    addTearDown(process.close);
    return process;
  }

  Future<String> collectUntil(
    Stream<List<int>> output,
    String marker, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final buffer = StringBuffer();
    await for (final chunk in output.timeout(timeout)) {
      buffer.write(utf8.decode(chunk, allowMalformed: true));
      if (buffer.toString().contains(marker)) break;
    }
    return buffer.toString();
  }

  Future<String> drain(Stream<List<int>> output) async {
    final buffer = StringBuffer();
    await for (final chunk in output) {
      buffer.write(utf8.decode(chunk, allowMalformed: true));
    }
    return buffer.toString();
  }

  group('terminal', () {
    test(
      'runs a child under a pseudoconsole and reports its exit code',
      () async {
        final process = spawn(
          host.terminal(
            executable: cmd,
            environment: Platform.environment,
            arguments: const ['/c', 'echo HELLOMARKER& exit 42'],
            launchMode: ShellLaunchMode.raw,
            forwardHostResize: false,
          ),
        );

        final output = await collectUntil(process.stdout, 'HELLOMARKER');
        expect(output, contains('HELLOMARKER'));
        expect(
          await process.exit.timeout(const Duration(seconds: 5)),
          const ProcessExited(42),
        );
      },
    );

    test('forwards typed input to the child', () async {
      final process = spawn(
        host.terminal(
          executable: cmd,
          environment: Platform.environment,
          arguments: const ['/q'],
          launchMode: ShellLaunchMode.raw,
          forwardHostResize: false,
        ),
      )..writeString('echo TYPED_BACK\r\nexit\r\n');

      final output = await collectUntil(process.stdout, 'TYPED_BACK');
      expect(output, contains('TYPED_BACK'));
      await process.exit.timeout(const Duration(seconds: 5));
    });

    test('terminates a running child on kill', () async {
      final process = spawn(
        host.terminal(
          executable: cmd,
          environment: Platform.environment,
          arguments: const ['/c', 'ping -n 30 127.0.0.1 >nul'],
          launchMode: ShellLaunchMode.raw,
          forwardHostResize: false,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(await process.kill(force: true), isTrue);
      expect(
        await process.exit.timeout(const Duration(seconds: 5)),
        isA<ProcessExited>(),
      );
    });
  });

  group('piped', () {
    test('splits stdout and stderr and reports the exit code', () async {
      final process = spawn(
        host.piped(
          executable: cmd,
          environment: Platform.environment,
          arguments: const ['/c', 'echo TO_OUT& echo TO_ERR 1>&2& exit 5'],
        ),
      );

      final out = drain(process.stdout);
      final err = drain(process.stderr);
      final exit = await process.exit.timeout(const Duration(seconds: 5));

      expect((await out).trim(), contains('TO_OUT'));
      expect((await err).trim(), contains('TO_ERR'));
      expect(exit, const ProcessExited(5));
    });

    test('rejects writes once stdin is closed', () async {
      final process = spawn(
        host.piped(
          executable: cmd,
          environment: Platform.environment,
          arguments: const ['/c', 'more'],
        ),
      );
      await process.closeStdin();

      expect(() => process.writeString('hi'), throwsA(isA<StateError>()));

      await process.kill(force: true);
      await process.exit.timeout(const Duration(seconds: 5));
    });
  });
}
