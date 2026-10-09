import 'dart:async';

import 'package:clock/clock.dart';
import 'package:isolate_worker/isolate_worker.dart';
import 'package:mocktail/mocktail.dart';
import 'package:model_downloader/model_downloader.dart';
import 'package:model_downloader/src/transfer_progress.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Runs the isolate entry point on the current isolate. Isolates cannot be
/// mocked, and the generic spawn signature defeats mocktail.
class _InProcessSpawner implements IsolateSpawner {
  const _InProcessSpawner();

  @override
  Future<SpawnedIsolate> spawn<Message>(
    void Function(Message message) entryPoint,
    Message message, {
    String? debugName,
  }) async {
    entryPoint(message);
    return _ExitedIsolate();
  }
}

class _ExitedIsolate implements SpawnedIsolate {
  @override
  Future<void> get onExit => Future.value();

  @override
  void kill() {}

  @override
  void cleanup() {}
}

class _FailingSpawner implements IsolateSpawner {
  const _FailingSpawner();

  @override
  Future<SpawnedIsolate> spawn<Message>(
    void Function(Message message) entryPoint,
    Message message, {
    String? debugName,
  }) => throw StateError('no isolates today');
}

class _MockClock extends Mock implements Clock {}

/// Lets an emitted event reach the listener before the clock moves on.
Future<void> _delivered() => Future<void>.delayed(Duration.zero);

const _job = DownloadJob(
  directory: '/models',
  files: [
    DownloadFile(
      url: 'https://example.com/a.gguf',
      relativePath: 'a.gguf',
      bytes: 300,
    ),
    DownloadFile(
      url: 'https://example.com/b.gguf',
      relativePath: 'b.gguf',
      bytes: 100,
    ),
  ],
);

void main() {
  late _MockClock clock;
  late DateTime now;

  setUp(() {
    clock = _MockClock();
    now = DateTime.utc(2026, 10, 4);
    when(() => clock.now()).thenAnswer((_) => now);
  });

  ModelDownloader downloader(
    IsolateCommandHandler<DownloadJob, DownloadResult> handler, {
    IsolateSpawner spawner = const _InProcessSpawner(),
  }) => ModelDownloader(
    isolateSpawner: spawner,
    clock: clock,
    commandHandler: handler,
  );

  String describe(DownloadProgress update) =>
      '${update.phase.name} ${update.receivedBytes}/${update.totalBytes} '
      '${update.speedBytesPerSecond?.round()}';

  test('reports job progress with speed, then the result', () async {
    final run = downloader((job, context) async {
      now = now.add(const Duration(seconds: 1));
      context.events.emit(
        const TransferProgress(
          phase: DownloadPhase.downloading,
          receivedBytes: 100,
          transferredBytes: 100,
        ),
      );
      await _delivered();
      now = now.add(const Duration(seconds: 2));
      context.events.emit(
        const TransferProgress(
          phase: DownloadPhase.downloading,
          receivedBytes: 300,
          transferredBytes: 300,
        ),
      );
      await _delivered();
      now = now.add(const Duration(seconds: 1));
      context.events.emit(
        const TransferProgress(
          phase: DownloadPhase.verifying,
          receivedBytes: 400,
          transferredBytes: 400,
        ),
      );
      return const DownloadCompleted();
    }).start(_job);

    final progress = await run.progress.toList();

    expect(await run.result, isA<DownloadCompleted>());
    expect(
      progress.map(describe),
      [
        'downloading 100/400 100',
        'downloading 300/400 100',
        'verifying 400/400 100',
      ],
    );
  });

  test('leaves bytes kept from an earlier attempt out of the speed', () async {
    final run = downloader((job, context) async {
      now = now.add(const Duration(seconds: 2));
      context.events.emit(
        const TransferProgress(
          phase: DownloadPhase.downloading,
          receivedBytes: 300,
          transferredBytes: 200,
        ),
      );
      await _delivered();
      now = now.add(const Duration(seconds: 2));
      context.events.emit(
        const TransferProgress(
          phase: DownloadPhase.downloading,
          receivedBytes: 390,
          transferredBytes: 200,
        ),
      );
      return const DownloadCompleted();
    }).start(_job);

    final progress = await run.progress.toList();

    expect(progress.map(describe), [
      'downloading 300/400 100',
      'downloading 390/400 50',
    ]);
  });

  test('has no speed before any time has passed', () async {
    final run = downloader((job, context) async {
      context.events.emit(
        const TransferProgress(
          phase: DownloadPhase.downloading,
          receivedBytes: 50,
          transferredBytes: 50,
        ),
      );
      return const DownloadCompleted();
    }).start(_job);

    final progress = await run.progress.single;

    expect(progress.speedBytesPerSecond, isNull);
  });

  test('never reports a negative speed', () async {
    final run = downloader((job, context) async {
      now = now.add(const Duration(seconds: 1));
      context.events.emit(
        const TransferProgress(
          phase: DownloadPhase.downloading,
          receivedBytes: 10,
          transferredBytes: -10,
        ),
      );
      return const DownloadCompleted();
    }).start(_job);

    final progress = await run.progress.toList();

    expect(progress.last.speedBytesPerSecond, 0);
  });

  test('passes the handler result through', () async {
    const failure = DownloadFailed(DownloadDiskFull());
    final run = downloader((job, context) => failure).start(_job);

    expect(await run.result, same(failure));
    expect(await run.progress.isEmpty, isTrue);
  });

  test('cancel reaches the running handler', () async {
    final started = Completer<void>();
    final run = downloader((job, context) async {
      started.complete();
      await context.cancellationToken.cancelled;
      return const DownloadCancelled();
    }).start(_job);

    await started.future;
    run
      ..cancel()
      ..cancel();

    expect(await run.result, isA<DownloadCancelled>());
  });

  test('cancel before the isolate starts still reaches the handler', () async {
    final run = downloader((job, context) async {
      await context.cancellationToken.cancelled;
      return const DownloadCancelled();
    }).start(_job)..cancel();

    expect(await run.result, isA<DownloadCancelled>());
  });

  test('reports a crashed handler as a failure', () async {
    final run = downloader(
      (job, context) => throw StateError('boom'),
    ).start(_job);

    expect(
      await run.result,
      isA<DownloadFailed>()
          .having(
            (result) => result.reason,
            'reason',
            isA<DownloadWorkerError>(),
          )
          .having((result) => result.message, 'message', contains('boom')),
    );
  });

  test('reports an isolate that cannot start as a failure', () async {
    final run = downloader(
      (job, context) => const DownloadCompleted(),
      spawner: const _FailingSpawner(),
    ).start(_job);

    expect(
      await run.result,
      isA<DownloadFailed>()
          .having(
            (result) => result.reason,
            'reason',
            isA<DownloadWorkerError>(),
          )
          .having(
            (result) => result.message,
            'message',
            contains('no isolates today'),
          ),
    );
    expect(await run.progress.isEmpty, isTrue);
  });

  test('defaults to the real download handler', () async {
    final run =
        ModelDownloader(
          isolateSpawner: const _InProcessSpawner(),
        ).start(
          const DownloadJob(
            directory: '/models',
            files: [
              DownloadFile(
                url: 'https://example.com/x',
                relativePath: '../x',
                bytes: 1,
              ),
            ],
          ),
        );

    expect(await run.result, isA<DownloadFailed>());
  });

  test('DownloadJob totals bytes and resolves target paths', () {
    expect(_job.totalBytes, 400);
    expect(
      _job.targetPathFor(_job.files.first),
      p.join(p.separator, 'models', 'a.gguf'),
    );
    expect(
      _job.escapes(
        const DownloadFile(url: '', relativePath: 'sub/../a.gguf', bytes: 0),
      ),
      isFalse,
    );
    expect(
      _job.escapes(
        const DownloadFile(url: '', relativePath: '/etc/passwd', bytes: 0),
      ),
      isTrue,
    );
  });
}
