import 'dart:convert';
import 'dart:typed_data';

import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:mocktail/mocktail.dart';
import 'package:process_host_posix/process_host_posix.dart';
import 'package:sandbox/sandbox.dart';
import 'package:sandbox_linux/sandbox_linux.dart';
import 'package:test/test.dart';

class _MockKernelProbe extends Mock implements KernelProbe {}

/// Splits a wire program into its NUL-delimited fields.
List<String> wireFields(Uint8List bytes) {
  final parts = utf8.decode(bytes).split('\x00');
  if (parts.isNotEmpty && parts.last.isEmpty) parts.removeLast();
  return parts;
}

void main() {
  late _MockKernelProbe kernel;
  late FileSystem fs;

  setUp(() {
    kernel = _MockKernelProbe();
    fs = MemoryFileSystem();
    when(() => kernel.landlockAvailable()).thenAnswer((_) async => true);
    when(() => kernel.netnsAvailable()).thenAnswer((_) async => true);
  });

  SandboxLinux guard() => SandboxLinux(fileSystem: fs, kernelProbe: kernel);

  test('an unavailable Landlock kernel yields SandboxUnavailable', () async {
    when(() => kernel.landlockAvailable()).thenAnswer((_) async => false);

    final acquisition = await guard().acquire(
      const SandboxSpec(workspaceRoot: '/work'),
    );

    expect(acquisition, isA<SandboxUnavailable>());
  });

  test('a successful acquire reports the landlock backend and roots', () async {
    final acquisition = await guard().acquire(
      const SandboxSpec(
        workspaceRoot: '/work',
        readableRoots: ['/usr'],
      ),
    );

    final acquired = acquisition as SandboxAcquired;
    expect(acquired.enforcement.backend, 'landlock');
    expect(acquired.enforcement.enforced, {
      SandboxCapability.filesystemRead,
      SandboxCapability.filesystemWrite,
    });
    expect(acquired.enforcement.readableRoots, contains('/usr'));
    expect(acquired.enforcement.writableRoots, contains('/work'));
    // The sandbox carries the lowered grant program.
    final sandbox = acquired.sandbox as PosixSandbox;
    expect(wireFields(sandbox.confineProgram).first, 'sandbox/1');
  });

  test('the requested network tier is enforced when eligible', () async {
    final acquisition = await guard().acquire(
      const SandboxSpec(workspaceRoot: '/work', network: NetworkTier.local),
    );

    final acquired = acquisition as SandboxAcquired;
    expect(
      acquired.enforcement.network,
      isA<NetworkConfined>().having(
        (n) => n.tier,
        'tier',
        NetworkTier.local,
      ),
    );
    final sandbox = acquired.sandbox as PosixSandbox;
    expect(wireFields(sandbox.confineProgram)[1], 'local');
  });

  test('local degrades to none when netns is unavailable', () async {
    when(() => kernel.netnsAvailable()).thenAnswer((_) async => false);

    final acquisition = await guard().acquire(
      const SandboxSpec(workspaceRoot: '/work', network: NetworkTier.local),
    );

    final acquired = acquisition as SandboxAcquired;
    // Reported ineligible for the caller/UI...
    expect(
      acquired.enforcement.network,
      isA<NetworkIneligibleForConfinement>().having(
        (n) => n.requested,
        'requested',
        NetworkTier.local,
      ),
    );
    // ...and the wire fails closed to the more restrictive `none`, never `all`.
    final sandbox = acquired.sandbox as PosixSandbox;
    expect(wireFields(sandbox.confineProgram)[1], 'none');
  });

  test('a denied read is enumerated away and reported', () async {
    fs.directory('/home/joanna').createSync(recursive: true);
    fs.directory('/home/joanna/.ssh').createSync();
    fs.file('/home/joanna/.bashrc').createSync();

    final acquisition = await guard().acquire(
      const SandboxSpec(
        workspaceRoot: '/work',
        readableRoots: ['/home/joanna'],
        deniedReads: ['/home/joanna/.ssh'],
      ),
    );

    final acquired = acquisition as SandboxAcquired;
    expect(acquired.enforcement.deniedReads, contains('/home/joanna/.ssh'));
    // The parent is list-only and the secret is never granted read.
    final sandbox = acquired.sandbox as PosixSandbox;
    final fields = wireFields(sandbox.confineProgram);
    expect(fields, containsAllInOrder(['l', '/home/joanna']));
    expect(fields, contains('/home/joanna/.bashrc'));
    expect(fields, isNot(contains('/home/joanna/.ssh')));
  });
}
