import 'package:isolate_worker/isolate_worker.dart';
import 'package:mocktail/mocktail.dart';
import 'package:model_downloader/model_downloader.dart';
import 'package:model_downloader/src/chunked_file_downloader.dart';
import 'package:model_downloader/src/download_command_handler.dart';
import 'package:model_downloader/src/file_transfer.dart';
import 'package:model_downloader/src/transfer_progress.dart';
import 'package:test/test.dart';

class _MockEngine extends Mock implements ChunkedFileDownloader {}

class _MockSink extends Mock implements IsolateEventSink {}

const _first = DownloadFile(
  url: 'https://example.com/model-00001-of-00002.gguf',
  relativePath: 'model-00001-of-00002.gguf',
  bytes: 100,
  sha256: 'aaa',
);

const _second = DownloadFile(
  url: 'https://example.com/model-00002-of-00002.gguf',
  relativePath: 'model-00002-of-00002.gguf',
  bytes: 50,
);

const _job = DownloadJob(directory: '/models/repo', files: [_first, _second]);

FileTransfer _transfer(List<FileProgress> progress, FileOutcome outcome) =>
    FileTransfer(
      progress: Stream.fromIterable(progress),
      outcome: Future.value(outcome),
    );

void main() {
  late _MockEngine engine;
  late _MockSink sink;
  late IsolateCancellationTokenSource cancellation;

  setUpAll(
    () => registerFallbackValue(const NeverCancelledIsolateCancellationToken()),
  );

  setUp(() {
    engine = _MockEngine();
    sink = _MockSink();
    cancellation = IsolateCancellationTokenSource();
  });

  IsolateRequestContext context() => IsolateRequestContext(
    cancellationToken: cancellation.token,
    events: sink,
  );

  void stubFile(DownloadFile file, FileTransfer transfer) => when(
    () => engine.download(
      url: file.url,
      targetPath: any(named: 'targetPath'),
      expectedBytes: any(named: 'expectedBytes'),
      expectedSha256: any(named: 'expectedSha256'),
      workers: any(named: 'workers'),
      cancellation: any(named: 'cancellation'),
    ),
  ).thenAnswer((_) => transfer);

  DownloadCommandHandler handler() => DownloadCommandHandler(
    engineFactory: () => engine,
    progressStepBytes: 40,
    workersPerFile: 3,
  );

  List<String> emitted() => [
    for (final event in verify(() => sink.emit(captureAny())).captured)
      [
        (event as TransferProgress).phase.name,
        '${event.receivedBytes}/${event.transferredBytes}',
      ].join(':'),
  ];

  test('downloads files in order and reports job-wide progress', () async {
    stubFile(
      _first,
      _transfer(const [
        FileBytesReceived(0),
        FileBytesReceived(30),
        FileBytesReceived(45),
        FileBytesReceived(100),
        FileVerifying(),
        FileBytesReceived(100),
      ], const FileDownloaded()),
    );
    stubFile(
      _second,
      _transfer(const [
        FileBytesReceived(10),
        FileBytesReceived(50),
      ], const FileDownloaded()),
    );

    final result = await handler().call(_job, context());

    expect(result, isA<DownloadCompleted>());
    expect(emitted(), [
      'downloading:0/0',
      'downloading:45/45',
      'downloading:100/100',
      'verifying:100/100',
      'downloading:100/100',
      'downloading:110/110',
      'downloading:150/150',
    ]);
    verify(
      () => engine.download(
        url: _first.url,
        targetPath: '/models/repo/model-00001-of-00002.gguf',
        expectedBytes: 100,
        expectedSha256: 'aaa',
        workers: 3,
        cancellation: cancellation.token,
      ),
    ).called(1);
    verify(engine.close).called(1);
  });

  test('counts only bytes fetched by this attempt as transferred', () async {
    stubFile(
      _first,
      _transfer(const [
        FileVerifying(),
        FileBytesReceived(100, keptBytes: 100),
      ], const FileDownloaded()),
    );
    stubFile(
      _second,
      _transfer(const [
        FileBytesReceived(20, keptBytes: 20),
        FileBytesReceived(30, keptBytes: 20),
        FileBytesReceived(50, keptBytes: 20),
      ], const FileDownloaded()),
    );

    await handler().call(_job, context());

    expect(emitted(), [
      'verifying:100/0',
      'downloading:100/0',
      'downloading:120/0',
      'downloading:150/30',
    ]);
  });

  test('stops at a checksum mismatch', () async {
    stubFile(
      _first,
      _transfer(
        const [],
        const FileChecksumMismatch(expected: 'aaa', actual: 'bbb'),
      ),
    );

    final result = await handler().call(_job, context());

    expect(
      result,
      isA<DownloadChecksumMismatch>()
          .having((it) => it.file, 'file', _first)
          .having((it) => it.expected, 'expected', 'aaa')
          .having((it) => it.actual, 'actual', 'bbb'),
    );
    verifyNever(
      () => engine.download(
        url: _second.url,
        targetPath: any(named: 'targetPath'),
        expectedBytes: any(named: 'expectedBytes'),
        expectedSha256: any(named: 'expectedSha256'),
        workers: any(named: 'workers'),
        cancellation: any(named: 'cancellation'),
      ),
    );
    verify(engine.close).called(1);
  });

  test('stops when cancelled', () async {
    stubFile(_first, _transfer(const [], const FileDownloaded()));
    stubFile(_second, _transfer(const [], const FileCancelled()));

    expect(await handler().call(_job, context()), isA<DownloadCancelled>());
  });

  test('stops at a failure, naming the file', () async {
    stubFile(
      _first,
      _transfer(const [], const FileFailed(DownloadHttpStatus(502))),
    );

    final result = await handler().call(_job, context());

    expect(
      result,
      isA<DownloadFailed>()
          .having((it) => it.message, 'message', contains('HTTP 502'))
          .having((it) => it.file, 'file', _first),
    );
  });

  test('refuses files that would land outside the directory', () async {
    const escaping = DownloadFile(
      url: 'https://example.com/evil',
      relativePath: '../../etc/evil',
      bytes: 1,
    );

    final result = await handler().call(
      const DownloadJob(directory: '/models/repo', files: [_first, escaping]),
      context(),
    );

    expect(
      result,
      isA<DownloadFailed>()
          .having((it) => it.file, 'file', escaping)
          .having((it) => it.reason, 'reason', isA<DownloadUnsafePath>())
          .having((it) => it.message, 'message', contains('outside')),
    );
    verifyZeroInteractions(engine);
  });

  test('builds a real engine by default', () {
    expect(DownloadCommandHandler.localEngine(), isA<ChunkedFileDownloader>());
  });
}
