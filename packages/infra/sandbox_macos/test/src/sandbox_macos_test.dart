import 'package:file/memory.dart';
import 'package:mocktail/mocktail.dart';
import 'package:process_host/process_host.dart';
import 'package:process_host_posix/process_host_posix.dart';
import 'package:sandbox/sandbox.dart';
import 'package:sandbox_macos/sandbox_macos.dart';
import 'package:test/test.dart';

class _MockSandbox extends Mock implements Sandbox {}

void main() {
  late SandboxMacos sandboxBackend;

  setUp(() {
    // An empty in-memory tree: unresolvable allow roots fall back to the path
    // as given, so a spec over paths that do not exist still lowers.
    sandboxBackend = SandboxMacos(fileSystem: MemoryFileSystem());
  });

  String magicOf(PosixSandbox sandbox) =>
      String.fromCharCodes(sandbox.confineProgram.takeWhile((b) => b != 0));

  test('acquires a confined sandbox carrying its wire program', () async {
    final acquisition = await sandboxBackend.acquire(
      const SandboxSpec(workspaceRoot: '/work', readableRoots: ['/usr']),
    );

    expect(acquisition, isA<SandboxAcquired>());
    final acquired = acquisition as SandboxAcquired;
    final sandbox = acquired.sandbox;
    expect(sandbox, isA<PosixSandbox>());
    expect(magicOf(sandbox as PosixSandbox), wireMagic);
    expect(sandbox, isA<ConfinedSandbox>());
  });

  test('reports both fs dimensions and the workspace as writable', () async {
    final acquired =
        await sandboxBackend.acquire(const SandboxSpec(workspaceRoot: '/work'))
            as SandboxAcquired;

    expect(acquired.enforcement.backend, 'seatbelt');
    expect(
      acquired.enforcement.enforced,
      {SandboxCapability.filesystemRead, SandboxCapability.filesystemWrite},
    );
    expect(acquired.enforcement.writableRoots, contains('/work'));
  });

  test('confines network for the all tier', () async {
    final acquired =
        await sandboxBackend.acquire(const SandboxSpec(workspaceRoot: '/work'))
            as SandboxAcquired;

    expect(
      acquired.enforcement.network,
      const NetworkConfined(NetworkTier.all),
    );
  });

  test('confines the local and none tiers, never ineligible', () async {
    for (final tier in [NetworkTier.local, NetworkTier.none]) {
      final acquired =
          await sandboxBackend.acquire(
                SandboxSpec(workspaceRoot: '/work', network: tier),
              )
              as SandboxAcquired;

      expect(acquired.enforcement.network, NetworkConfined(tier));
    }
  });

  test('keeps a deny on a missing path rather than refusing', () async {
    final acquired =
        await sandboxBackend.acquire(
              const SandboxSpec(
                workspaceRoot: '/work',
                deniedReads: ['/home/.aws'],
              ),
            )
            as SandboxAcquired;

    expect(acquired.enforcement.deniedReads, contains('/home/.aws'));
  });

  test('release is a no-op', () {
    expect(sandboxBackend.release(_MockSandbox()), completes);
  });
}
