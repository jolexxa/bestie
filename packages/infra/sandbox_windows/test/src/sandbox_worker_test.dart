import 'package:isolate_worker/isolate_worker.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sandbox/sandbox.dart';
import 'package:sandbox_windows/sandbox_windows.dart';
import 'package:sandbox_windows/src/provision_protocol.dart';
import 'package:test/test.dart';

class _MockIsolateWorker extends Mock
    implements IsolateWorker<ProvisionRequest, ProvisionResponse> {}

/// An [IsolateSpawner] that always fails, to drive the spawn-failure arm
/// without touching a real isolate.
final class _ThrowingSpawner implements IsolateSpawner {
  const _ThrowingSpawner();

  @override
  Future<SpawnedIsolate> spawn<Message>(
    void Function(Message message) entryPoint,
    Message message, {
    String? debugName,
  }) => throw StateError('spawn refused');
}

void main() {
  setUpAll(() {
    registerFallbackValue(
      const ReverseSharedRead(capabilitySid: 'S', readRoots: [], holes: []),
    );
  });

  group('spawn', () {
    test('maps a spawn failure', () async {
      final result = await Win32SandboxWorker.spawn(
        isolateSpawner: const _ThrowingSpawner(),
      );

      expect(
        result,
        isA<SandboxWorkerCreateFailed>().having(
          (f) => f.message,
          'message',
          contains('spawn refused'),
        ),
      );
    });

    test('spawns a live worker that answers requests', () async {
      final result = await Win32SandboxWorker.spawn();
      final worker = (result as SandboxWorkerCreateSucceeded).worker;

      // An empty shared-read reversal touches nothing, so the round-trip stays
      // off the native surface while proving the isolate answers.
      final response = await worker.send(
        const ReverseSharedRead(capabilitySid: 'S', readRoots: [], holes: []),
      );

      expect(response, isA<Reversed>());
      await worker.close();
    });
  });

  group('send', () {
    late _MockIsolateWorker inner;
    late Win32SandboxWorker worker;

    setUp(() {
      inner = _MockIsolateWorker();
      worker = Win32SandboxWorker(inner);
    });

    test('unwraps a succeeded result', () async {
      const applied = ProvisionApplied(
        containerSid: 'S-1-15-2-test',
        tempDir: '/pkg/AC/Temp',
        network: NetworkConfined(NetworkTier.none),
        loopbackExempted: false,
      );
      when(
        () => inner.send(any()),
      ).thenAnswer((_) async => const IsolateSucceeded(applied));

      expect(
        await worker.send(
          const ReverseSharedRead(
            capabilitySid: 'S-1',
            readRoots: [],
            holes: [],
          ),
        ),
        applied,
      );
    });

    test('maps an isolate failure to a provisioning failure', () async {
      when(() => inner.send(any())).thenAnswer(
        (_) async => const IsolateRemoteFailed(
          message: 'worker died',
          stackTrace: '',
        ),
      );

      final response = await worker.send(
        const ReverseSharedRead(capabilitySid: 'S-1', readRoots: [], holes: []),
      );

      expect(
        response,
        isA<ProvisionFailedResponse>().having(
          (f) => f.reason,
          'reason',
          'worker died',
        ),
      );
    });

    test('close shuts the inner worker down', () async {
      when(() => inner.close()).thenAnswer((_) async {});

      await worker.close();

      verify(() => inner.close()).called(1);
    });
  });
}
