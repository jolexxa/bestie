import 'dart:async';
import 'dart:convert';
import 'dart:io'
    show FileMode, FileSystemException, HttpStatus, OSError, SocketException;

import 'package:fake_async/fake_async.dart';
import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:isolate_worker/isolate_worker.dart';
import 'package:mocktail/mocktail.dart';
import 'package:model_downloader/src/chunked_file_downloader.dart';
import 'package:model_downloader/src/download_failure.dart';
import 'package:model_downloader/src/file_hasher.dart';
import 'package:model_downloader/src/file_transfer.dart';
import 'package:test/test.dart';

import 'support/range_server.dart';

class _MockHasher extends Mock implements FileHasher {}

class _MockFile extends Mock implements File {}

class _MockToken extends Mock implements IsolateCancellationToken {}

class _MockHttpClient extends Mock implements http.Client {}

const _correctHash =
    '5faa4eec3611556812c2d74b437c8c49add3f910f10063d801441f7d75cd5e3b';
const _wrongHash =
    '0000000000000000000000000000000000000000000000000000000000000000';

final _payload = List<int>.generate(40, (index) => index);

void main() {
  late MemoryFileSystem fileSystem;
  const directory = '/models';

  setUpAll(() {
    registerFallbackValue(MemoryFileSystem.test().file('/x'));
    registerFallbackValue(http.Request('GET', Uri()));
    registerFallbackValue(const NeverCancelledIsolateCancellationToken());
  });

  setUp(() {
    fileSystem = MemoryFileSystem.test();
    fileSystem.directory(directory).createSync();
  });

  ChunkedFileDownloader downloader(
    http.Client client, {
    int chunkSizeBytes = 10,
    int writeBufferBytes = 4 * 1024 * 1024,
    int manifestFlushBytes = 64 * 1024 * 1024,
    int maxChunkRetries = 5,
    Duration idleTimeout = const Duration(seconds: 30),
    FileHasher hasher = const FileHasher(),
  }) => ChunkedFileDownloader(
    fileSystem: fileSystem,
    client: client,
    hasher: hasher,
    chunkSizeBytes: chunkSizeBytes,
    writeBufferBytes: writeBufferBytes,
    manifestFlushBytes: manifestFlushBytes,
    maxChunkRetries: maxChunkRetries,
    retryBaseDelay: Duration.zero,
    idleTimeout: idleTimeout,
  );

  String target(String name) => '$directory/$name';

  File file(String path) => fileSystem.file(path);

  void seedPart(String targetPath, List<int> bytes) =>
      file('$targetPath.part').writeAsBytesSync(bytes);

  void seedManifest(
    String targetPath, {
    required String url,
    required List<List<int>> chunks,
    int totalBytes = 40,
    int version = 1,
  }) => file('$targetPath.part.meta').writeAsStringSync(
    jsonEncode({
      'version': version,
      'url': url,
      'totalBytes': totalBytes,
      'chunks': [
        for (final chunk in chunks)
          {'start': chunk[0], 'end': chunk[1], 'received': chunk[2]},
      ],
    }),
  );

  Future<CollectedTransfer> run(
    ChunkedFileDownloader engine,
    String name, {
    String? url,
    int expectedBytes = 40,
    String? expectedSha256,
    int workers = 4,
    IsolateCancellationToken cancellation =
        const NeverCancelledIsolateCancellationToken(),
  }) => collect(
    engine.download(
      url: url ?? 'https://example.com/$name',
      targetPath: target(name),
      expectedBytes: expectedBytes,
      expectedSha256: expectedSha256,
      workers: workers,
      cancellation: cancellation,
    ),
  );

  void expectDownloaded(String name, [List<int>? bytes]) {
    expect(file(target(name)).readAsBytesSync(), bytes ?? _payload);
    expect(file('${target(name)}.part').existsSync(), isFalse);
    expect(file('${target(name)}.part.meta').existsSync(), isFalse);
  }

  Map<String, Object?> manifestOf(String name) =>
      jsonDecode(file('${target(name)}.part.meta').readAsStringSync())
          as Map<String, Object?>;

  List<Object?> receivedPerChunk(String name) => [
    for (final chunk in manifestOf(name)['chunks']! as List<Object?>)
      (chunk! as Map<String, Object?>)['received'],
  ];

  Matcher failedWith(Matcher failure) => isA<FileFailed>().having(
    (outcome) => outcome.reason,
    'reason',
    failure,
  );

  void expectResumable(String name) {
    expect(file('${target(name)}.part').existsSync(), isTrue);
    expect(file('${target(name)}.part.meta').existsSync(), isTrue);
    expect(file(target(name)).existsSync(), isFalse);
  }

  group('ChunkedFileDownloader', () {
    test('keeps an existing target of the expected size', () async {
      file(target('model.bin')).writeAsBytesSync([1, 2, 3]);
      final engine = downloader(
        MockClient((_) => fail('no request for an existing file')),
      );

      final result = await run(engine, 'model.bin', expectedBytes: 3);

      expect(result.bytes, [3]);
      expect(
        (result.events.single as FileBytesReceived).keptBytes,
        3,
        reason: 'kept bytes are not part of this transfer',
      );
      expect(result.outcome, isA<FileDownloaded>());
    });

    test('keeps an existing target whose sha256 matches', () async {
      file(target('verified-existing.bin')).writeAsBytesSync(_payload);
      final engine = downloader(
        MockClient((_) => fail('no request for a verified file')),
      );

      final result = await run(
        engine,
        'verified-existing.bin',
        expectedSha256: _correctHash,
      );

      expect(result.events.first, isA<FileVerifying>());
      expect(result.outcome, isA<FileDownloaded>());
      expectDownloaded('verified-existing.bin');
    });

    test('downloads again over an existing target of the wrong size', () async {
      file(target('short-existing.bin')).writeAsBytesSync([1, 2, 3]);

      final result = await run(
        downloader(rangeServingClient(_payload)),
        'short-existing.bin',
      );

      expect(result.outcome, isA<FileDownloaded>());
      expectDownloaded('short-existing.bin');
    });

    test('downloads again over an existing target with a bad sha256', () async {
      file(target('corrupt-existing.bin')).writeAsBytesSync(List.filled(40, 0));

      final result = await run(
        downloader(rangeServingClient(_payload)),
        'corrupt-existing.bin',
        expectedSha256: _correctHash,
      );

      expect(result.outcome, isA<FileDownloaded>());
      expectDownloaded('corrupt-existing.bin');
    });

    test('downloads a single-chunk file', () async {
      const payload = [5, 6, 7, 8];
      final engine = downloader(rangeServingClient(payload), chunkSizeBytes: 4);

      final result = await run(engine, 'tiny.bin', expectedBytes: 4);

      expect(result.outcome, isA<FileDownloaded>());
      expect(result.bytes.first, 0);
      expect(result.bytes.last, 4);
      for (var index = 1; index < result.bytes.length; index++) {
        expect(
          result.bytes[index],
          greaterThanOrEqualTo(result.bytes[index - 1]),
        );
      }
      expectDownloaded('tiny.bin', payload);
    });

    test('creates missing parent directories', () async {
      final engine = downloader(rangeServingClient(_payload));

      final result = await run(engine, 'nested/deeper/model.bin');

      expect(result.outcome, isA<FileDownloaded>());
      expectDownloaded('nested/deeper/model.bin');
    });

    test('downloads many chunks with one worker', () async {
      final engine = downloader(rangeServingClient(_payload));

      await run(engine, 'single.bin', workers: 1);

      expectDownloaded('single.bin');
    });

    test('downloads chunks in parallel', () async {
      final engine = downloader(rangeServingClient(_payload));

      final result = await run(engine, 'chunked.bin');

      expect(result.bytes.last, 40);
      expectDownloaded('chunked.bin');
    });

    test('writes the manifest mid-chunk once the flush threshold passes', () {
      fakeAsync((async) {
        void stallAfterEightBytes(String name, int manifestFlushBytes) {
          final stalled = StreamController<List<int>>();
          final engine = downloader(
            MockClient.streaming(
              (_, _) async => http.StreamedResponse(
                stalled.stream,
                HttpStatus.partialContent,
              ),
            ),
            chunkSizeBytes: 40,
            writeBufferBytes: 4,
            manifestFlushBytes: manifestFlushBytes,
          );
          unawaited(run(engine, name, workers: 1));
          async.elapse(Duration.zero);
          stalled.add(_payload.sublist(0, 8));
          async.elapse(Duration.zero);
        }

        stallAfterEightBytes('flush-early.bin', 8);
        stallAfterEightBytes('flush-late.bin', 1000);

        expect(receivedPerChunk('flush-early.bin'), [8]);
        expect(receivedPerChunk('flush-late.bin'), [0]);
      });
    });

    test('reports progress per packet despite buffered writes', () async {
      final payload = List<int>.generate(10, (index) => index);
      final client = MockClient.streaming((request, _) async {
        final range = RequestedRange(request);
        return http.StreamedResponse(
          streamOf([
            for (var index = range.start; index <= range.end; index++)
              [payload[index]],
          ]),
          HttpStatus.partialContent,
        );
      });
      final engine = downloader(client, writeBufferBytes: 4);

      final result = await run(
        engine,
        'coalesce.bin',
        expectedBytes: 10,
        workers: 1,
      );

      expect(result.bytes, [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 10]);
      expectDownloaded('coalesce.bin', payload);
    });

    test('keeps concurrency within the worker count', () async {
      var inFlight = 0;
      var maxInFlight = 0;
      final client = MockClient.streaming((request, _) async {
        inFlight++;
        if (inFlight > maxInFlight) maxInFlight = inFlight;
        final response = partialResponse(
          _payload,
          RequestedRange(request),
          delays: const [Duration(milliseconds: 5)],
        );
        return http.StreamedResponse(
          response.stream.transform(
            StreamTransformer.fromHandlers(
              handleDone: (sink) {
                inFlight--;
                sink.close();
              },
            ),
          ),
          HttpStatus.partialContent,
        );
      });
      final engine = downloader(client, chunkSizeBytes: 4);

      await run(engine, 'concurrency.bin', workers: 2);

      expectDownloaded('concurrency.bin');
      expect(maxInFlight, lessThanOrEqualTo(2));
    });

    test('lets a fast worker drain the queue past a slow one', () async {
      final starts = <int>[];
      final client = MockClient.streaming((request, _) async {
        final range = RequestedRange(request);
        starts.add(range.start);
        return partialResponse(
          _payload,
          range,
          delays: [Duration(milliseconds: range.start == 0 ? 80 : 5)],
        );
      });
      final engine = downloader(client);

      await run(engine, 'steal.bin', workers: 2);

      expectDownloaded('steal.bin');
      expect(starts.toSet(), {0, 10, 20, 30});
    });
  });

  group('ChunkedFileDownloader resume', () {
    const url = 'https://example.com/resume.bin';

    test('resumes a partial download without refetching done chunks', () async {
      final targetPath = target('resume.bin');
      seedPart(targetPath, List.filled(40, 0));
      file('$targetPath.part').openSync(mode: FileMode.append)
        ..setPositionSync(0)
        ..writeFromSync(_payload.sublist(0, 10))
        ..closeSync();
      seedManifest(
        targetPath,
        url: url,
        chunks: const [
          [0, 9, 10],
          [10, 19, 0],
          [20, 29, 0],
          [30, 39, 0],
        ],
      );
      final ranges = <String>[];
      final client = MockClient.streaming((request, _) async {
        final range = RequestedRange(request);
        ranges.add(range.header);
        return partialResponse(_payload, range);
      });

      final result = await run(downloader(client), 'resume.bin', url: url);

      expect(result.bytes.first, 10);
      expect(result.bytes.last, 40);
      expectDownloaded('resume.bin');
      expect(ranges.where((range) => range.startsWith('bytes=0-')), isEmpty);
    });

    test('finishes without requests when every chunk is done', () async {
      final targetPath = target('done.bin');
      seedPart(targetPath, _payload);
      seedManifest(
        targetPath,
        url: 'https://example.com/done.bin',
        chunks: const [
          [0, 19, 20],
          [20, 39, 20],
        ],
      );
      final engine = downloader(
        MockClient((_) => fail('no request when every chunk is done')),
        chunkSizeBytes: 20,
      );

      final result = await run(engine, 'done.bin', workers: 2);

      expect(result.outcome, isA<FileDownloaded>());
      expectDownloaded('done.bin');
    });

    test('starts over when the manifest does not match the request', () async {
      final stale = {
        'total-bytes': () => seedManifest(
          target('total-bytes'),
          url: 'https://example.com/total-bytes',
          totalBytes: 999,
          chunks: const [
            [0, 499, 100],
            [500, 998, 0],
          ],
        ),
        'url': () => seedManifest(
          target('url'),
          url: 'https://example.com/old.bin',
          chunks: const [
            [0, 9, 5],
            [10, 19, 0],
            [20, 29, 0],
            [30, 39, 0],
          ],
        ),
        'boundaries': () => seedManifest(
          target('boundaries'),
          url: 'https://example.com/boundaries',
          chunks: const [
            [0, 19, 5],
            [20, 39, 0],
          ],
        ),
        'version': () => seedManifest(
          target('version'),
          url: 'https://example.com/version',
          version: 999,
          chunks: const [
            [0, 9, 0],
            [10, 19, 0],
            [20, 29, 0],
            [30, 39, 0],
          ],
        ),
        'received': () => seedManifest(
          target('received'),
          url: 'https://example.com/received',
          chunks: const [
            [0, 9, 11],
            [10, 19, 0],
            [20, 29, 0],
            [30, 39, 0],
          ],
        ),
        'negative': () => seedManifest(
          target('negative'),
          url: 'https://example.com/negative',
          chunks: const [
            [0, 9, -1],
            [10, 19, 0],
            [20, 29, 0],
            [30, 39, 0],
          ],
        ),
        'corrupt': () =>
            file('${target('corrupt')}.part.meta').writeAsStringSync('{{{'),
      };

      for (final MapEntry(key: name, value: seed) in stale.entries) {
        seedPart(target(name), List.filled(40, 0));
        seed();

        final result = await run(
          downloader(rangeServingClient(_payload)),
          name,
        );

        expect(result.bytes.first, 0, reason: name);
        expectDownloaded(name);
      }
    });

    test('starts over when the .part file has the wrong length', () async {
      final targetPath = target('length.bin');
      seedPart(targetPath, List.filled(20, 0));
      seedManifest(
        targetPath,
        url: 'https://example.com/length.bin',
        chunks: const [
          [0, 9, 0],
          [10, 19, 0],
          [20, 29, 0],
          [30, 39, 0],
        ],
      );

      await run(downloader(rangeServingClient(_payload)), 'length.bin');

      expectDownloaded('length.bin');
    });

    test('clears orphaned resume artifacts', () async {
      seedPart(target('orphan-part.bin'), List.filled(20, 0));
      seedManifest(
        target('orphan-meta.bin'),
        url: 'https://example.com/orphan-meta.bin',
        chunks: const [
          [0, 39, 0],
        ],
      );
      final tempManifest = '${target('orphan-tmp.bin')}.part.meta.tmp';
      file(tempManifest).writeAsStringSync('partial-write-garbage');

      for (final name in [
        'orphan-part.bin',
        'orphan-meta.bin',
        'orphan-tmp.bin',
      ]) {
        await run(downloader(rangeServingClient(_payload)), name);

        expectDownloaded(name);
      }
      expect(file(tempManifest).existsSync(), isFalse);
    });
  });

  group('ChunkedFileDownloader without Range support', () {
    MockClient wholeFileClient(List<int> payload) => MockClient.streaming(
      (_, _) async => http.StreamedResponse(
        streamOf([payload]),
        HttpStatus.ok,
        contentLength: payload.length,
      ),
    );

    test('falls back to one stream when the probe gets 200', () async {
      var requests = 0;
      final client = MockClient.streaming((_, _) async {
        requests++;
        return http.StreamedResponse(streamOf([_payload]), HttpStatus.ok);
      });

      final result = await run(downloader(client), 'fallback.bin');

      expect(requests, 1);
      expect(result.bytes.last, 40);
      expectDownloaded('fallback.bin');
    });

    test('drops a stale manifest on fallback', () async {
      final targetPath = target('fallback-stale.bin');
      seedPart(targetPath, List.filled(40, 0));
      seedManifest(
        targetPath,
        url: 'https://example.com/fallback-stale.bin',
        chunks: const [
          [0, 19, 5],
          [20, 39, 0],
        ],
      );

      await run(
        downloader(wholeFileClient(_payload), chunkSizeBytes: 20),
        'fallback-stale.bin',
        workers: 2,
      );

      expectDownloaded('fallback-stale.bin');
    });

    test('verifies the sha256 on fallback too', () async {
      final engine = downloader(wholeFileClient(_payload));

      final wrong = await run(
        engine,
        'fallback-wrong.bin',
        expectedSha256: _wrongHash,
      );
      final right = await run(
        engine,
        'fallback-right.bin',
        expectedSha256: _correctHash,
      );

      expect(wrong.outcome, isA<FileChecksumMismatch>());
      expect(right.outcome, isA<FileDownloaded>());
      expectDownloaded('fallback-right.bin');
    });

    test('fails when the body ends before the expected size', () async {
      final result = await run(
        downloader(wholeFileClient(_payload.sublist(0, 39))),
        'fallback-short.bin',
      );

      expect(
        result.outcome,
        failedWith(
          isA<DownloadTruncated>()
              .having((it) => it.expectedBytes, 'expectedBytes', 40)
              .having((it) => it.receivedBytes, 'receivedBytes', 39),
        ),
      );
      expect(file(target('fallback-short.bin')).existsSync(), isFalse);
      expect(
        file('${target('fallback-short.bin')}.part.meta').existsSync(),
        isFalse,
      );
    });

    test('fails when the body runs past the expected size', () async {
      final result = await run(
        downloader(wholeFileClient([..._payload, 0])),
        'fallback-long.bin',
      );

      expect(result.outcome, failedWith(isA<DownloadTruncated>()));
      expect(file(target('fallback-long.bin')).existsSync(), isFalse);
    });

    test('cancels mid-stream', () async {
      final cancellation = IsolateCancellationTokenSource();
      final client = MockClient.streaming(
        (_, _) async => http.StreamedResponse(
          streamOf(
            const [
              [1, 2, 3],
              [4, 5, 6],
            ],
            delays: const [Duration.zero, Duration(milliseconds: 30)],
            onFirstChunk: () => Timer(
              const Duration(milliseconds: 5),
              cancellation.cancel,
            ),
          ),
          HttpStatus.ok,
        ),
      );

      final result = await run(
        downloader(client),
        'cancel-200.bin',
        expectedBytes: 6,
        cancellation: cancellation.token,
      );

      expect(result.outcome, isA<FileCancelled>());
    });
  });

  group('ChunkedFileDownloader failures', () {
    test('fails when the probe gets an error status', () async {
      final client = MockClient.streaming(
        (_, _) async => http.StreamedResponse(
          const Stream.empty(),
          HttpStatus.internalServerError,
        ),
      );

      final result = await run(
        downloader(client),
        'bad.bin',
        expectedBytes: 100,
      );

      expect(
        result.outcome,
        failedWith(
          isA<DownloadHttpStatus>().having(
            (it) => it.statusCode,
            'statusCode',
            HttpStatus.internalServerError,
          ),
        ),
      );
    });

    test('fails without retrying when the file is missing', () async {
      var requests = 0;
      final client = MockClient.streaming((_, _) async {
        requests++;
        return http.StreamedResponse(const Stream.empty(), HttpStatus.notFound);
      });

      final result = await run(downloader(client), 'missing.bin');

      expect(
        result.outcome,
        failedWith(
          isA<DownloadHttpStatus>().having(
            (it) => it.statusCode,
            'statusCode',
            HttpStatus.notFound,
          ),
        ),
      );
      expect(requests, 1);
    });

    test('fails when a worker chunk gets a non-206 status', () async {
      var requests = 0;
      final client = MockClient.streaming((request, _) async {
        requests++;
        if (requests == 1) {
          return partialResponse(_payload, RequestedRange(request));
        }
        return http.StreamedResponse(
          const Stream.empty(),
          HttpStatus.internalServerError,
        );
      });

      final result = await run(
        downloader(client, maxChunkRetries: 0),
        'worker-error.bin',
      );

      expect(
        result.outcome,
        failedWith(
          isA<DownloadHttpStatus>().having(
            (it) => it.statusCode,
            'statusCode',
            HttpStatus.internalServerError,
          ),
        ),
      );
    });

    test('keeps resume artifacts when a chunk stream errors', () async {
      final client = MockClient.streaming((request, _) async {
        final range = RequestedRange(request);
        return http.StreamedResponse(
          streamOf(
            [
              _payload.sublist(range.start, range.start + 1),
            ],
            error: Exception('boom'),
          ),
          HttpStatus.partialContent,
        );
      });

      final result = await run(
        downloader(client, maxChunkRetries: 0),
        'stream-err.bin',
      );

      expect(result.outcome, isA<FileFailed>());
      expectResumable('stream-err.bin');
    });

    test('fails when the request cannot be sent', () async {
      final client = _MockHttpClient();
      when(() => client.send(any())).thenThrow(
        const SocketException('offline'),
      );

      final result = await run(downloader(client), 'offline.bin');

      expect(
        result.outcome,
        failedWith(
          isA<DownloadNetworkError>().having(
            (it) => it.detail,
            'detail',
            contains('offline'),
          ),
        ),
      );
    });
  });

  group('ChunkedFileDownloader retries', () {
    http.StreamedResponse stall(List<int> bytesBeforeStall) =>
        http.StreamedResponse(
          streamOf(
            [
              for (final byte in bytesBeforeStall) [byte],
            ],
            error: const SocketException('stall'),
          ),
          HttpStatus.partialContent,
        );

    test('resumes a retried chunk from the last flushed byte', () async {
      final ranges = <String>[];
      var failed = false;
      final client = MockClient.streaming((request, _) async {
        final range = RequestedRange(request);
        ranges.add(range.header);
        if (range.start == 20 && !failed) {
          failed = true;
          return stall(_payload.sublist(20, 24));
        }
        return partialResponse(_payload, range);
      });

      await run(
        downloader(client, writeBufferBytes: 4),
        'retry-resume.bin',
        workers: 1,
      );

      expectDownloaded('retry-resume.bin');
      expect(ranges, contains('bytes=24-29'));
    });

    test('takes unwritten bytes back out of progress on retry', () async {
      var failed = false;
      final client = MockClient.streaming((request, _) async {
        final range = RequestedRange(request);
        if (range.start == 20 && !failed) {
          failed = true;
          return stall(_payload.sublist(20, 24));
        }
        return partialResponse(_payload, range);
      });

      final result = await run(
        downloader(client, writeBufferBytes: 1000),
        'retry-rollback.bin',
        workers: 1,
      );

      expectDownloaded('retry-rollback.bin');
      expect(result.bytes.every((bytes) => bytes <= 40), isTrue);
      expect(result.bytes.last, 40);
    });

    test('retries a non-206 chunk response', () async {
      var failed = false;
      final client = MockClient.streaming((request, _) async {
        final range = RequestedRange(request);
        if (range.start == 20 && !failed) {
          failed = true;
          return http.StreamedResponse(
            const Stream.empty(),
            HttpStatus.serviceUnavailable,
          );
        }
        return partialResponse(_payload, range);
      });

      await run(downloader(client), 'retry-503.bin', workers: 1);

      expectDownloaded('retry-503.bin');
    });

    test('gives up after the retry budget and keeps artifacts', () async {
      final client = MockClient.streaming((request, _) async {
        final range = RequestedRange(request);
        if (range.start == 20) return stall(const []);
        return partialResponse(_payload, range);
      });

      final result = await run(
        downloader(client, maxChunkRetries: 2),
        'retry-exhaust.bin',
        workers: 1,
      );

      expect(
        result.outcome,
        failedWith(
          isA<DownloadNetworkError>().having(
            (it) => it.detail,
            'detail',
            contains('stall'),
          ),
        ),
      );
      expectResumable('retry-exhaust.bin');
    });

    test('does not retry once cancellation is requested', () async {
      final cancellation = IsolateCancellationTokenSource();
      var chunkRequests = 0;
      final client = MockClient.streaming((request, _) async {
        final range = RequestedRange(request);
        if (range.start == 20) {
          chunkRequests++;
          cancellation.cancel();
          return stall(const []);
        }
        return partialResponse(_payload, range);
      });

      final result = await run(
        downloader(client),
        'retry-cancel.bin',
        workers: 1,
        cancellation: cancellation.token,
      );

      expect(result.outcome, isNot(isA<FileDownloaded>()));
      expect(chunkRequests, 1);
    });

    test('retries a stalled probe through the chunk path', () async {
      var probeFailed = false;
      final client = MockClient.streaming((request, _) async {
        final range = RequestedRange(request);
        if (range.start == 0 && !probeFailed) {
          probeFailed = true;
          return stall(const []);
        }
        return partialResponse(_payload, range);
      });

      await run(downloader(client), 'retry-probe.bin');

      expectDownloaded('retry-probe.bin');
      expect(probeFailed, isTrue);
    });
  });

  group('ChunkedFileDownloader cancellation', () {
    test('cancels before any request', () async {
      final cancellation = IsolateCancellationTokenSource()..cancel();
      final client = MockClient.streaming(
        (_, _) async => fail('no request after cancellation'),
      );

      final result = await run(
        downloader(client),
        'precancel.bin',
        cancellation: cancellation.token,
      );

      expect(result.outcome, isA<FileCancelled>());
    });

    test('keeps resume artifacts when cancelled mid-download', () async {
      final cancellation = IsolateCancellationTokenSource();
      final client = MockClient.streaming(
        (request, _) async => partialResponse(
          _payload,
          RequestedRange(request),
          delays: const [Duration(milliseconds: 10)],
          onFirstChunk: () =>
              Timer(const Duration(milliseconds: 1), cancellation.cancel),
        ),
      );

      final result = await run(
        downloader(client),
        'cancel.bin',
        cancellation: cancellation.token,
      );

      expect(result.outcome, isA<FileCancelled>());
      expectResumable('cancel.bin');
    });

    test('reads a request aborted by cancellation as cancelled', () async {
      final cancellation = IsolateCancellationTokenSource();
      final client = MockClient.streaming((request, _) async {
        final range = RequestedRange(request);
        if (range.start == 0) return partialResponse(_payload, range);
        final body = StreamController<List<int>>(sync: true);
        unawaited(
          (request as http.Abortable).abortTrigger!.then(
            (_) => body.addError(http.RequestAbortedException(request.url)),
          ),
        );
        body.add(_payload.sublist(range.start, range.start + 1));
        Timer(const Duration(milliseconds: 1), cancellation.cancel);
        return http.StreamedResponse(
          body.stream,
          HttpStatus.partialContent,
          contentLength: range.end - range.start + 1,
        );
      });

      final result = await run(
        downloader(client),
        'abort.bin',
        workers: 1,
        cancellation: cancellation.token,
      );

      expect(result.outcome, isA<FileCancelled>());
      expectResumable('abort.bin');
    });

    test('honours cancellation seen as a worker starts a chunk', () async {
      final cancellation = _MockToken();
      when(
        () => cancellation.cancelled,
      ).thenAnswer((_) => Completer<void>().future);
      var polls = 0;
      when(
        () => cancellation.isCancellationRequested,
      ).thenAnswer((_) => ++polls >= 3);

      final result = await run(
        downloader(rangeServingClient(_payload)),
        'chunk-start-cancel.bin',
        workers: 1,
        cancellation: cancellation,
      );

      expect(result.outcome, isA<FileCancelled>());
      expect(
        file('${target('chunk-start-cancel.bin')}.part').existsSync(),
        isTrue,
      );
    });

    test('keeps resume artifacts when cancelled while verifying', () async {
      final cancellation = IsolateCancellationTokenSource();
      final hasher = _MockHasher();
      when(
        () => hasher.sha256Of(
          any(),
          cancellation: any(named: 'cancellation'),
        ),
      ).thenAnswer((_) async {
        cancellation.cancel();
        return const FileHashCancelled();
      });

      final result = await run(
        downloader(rangeServingClient(_payload), hasher: hasher),
        'cancel-verify.bin',
        expectedSha256: _correctHash,
        cancellation: cancellation.token,
      );

      expect(result.outcome, isA<FileCancelled>());
      expectResumable('cancel-verify.bin');
    });
  });

  group('ChunkedFileDownloader incomplete bodies', () {
    MockClient shortBodies({required int shortBy, int times = 1 << 30}) {
      var served = 0;
      return MockClient.streaming((request, _) async {
        final range = RequestedRange(request);
        final body = _payload.sublist(range.start, range.end + 1);
        return http.StreamedResponse(
          streamOf([
            if (served++ < times)
              body.sublist(0, body.length - shortBy)
            else
              body,
          ]),
          HttpStatus.partialContent,
        );
      });
    }

    test('fails when a chunk body ends early without an error', () async {
      final result = await run(
        downloader(shortBodies(shortBy: 1), maxChunkRetries: 1),
        'short-chunk.bin',
        workers: 1,
      );

      expect(
        result.outcome,
        failedWith(
          isA<DownloadTruncated>()
              .having((it) => it.expectedBytes, 'expectedBytes', 1)
              .having((it) => it.receivedBytes, 'receivedBytes', 0),
        ),
      );
      expect(file(target('short-chunk.bin')).existsSync(), isFalse);
      expectResumable('short-chunk.bin');
      expect(receivedPerChunk('short-chunk.bin'), [9, 0, 0, 0]);
    });

    test('retries a chunk whose body ended early', () async {
      final result = await run(
        downloader(shortBodies(shortBy: 3, times: 1)),
        'short-then-whole.bin',
        workers: 1,
      );

      expect(result.outcome, isA<FileDownloaded>());
      expectDownloaded('short-then-whole.bin');
    });

    test('fails when a chunk body runs past its range', () async {
      final client = MockClient.streaming((request, _) async {
        final range = RequestedRange(request);
        return http.StreamedResponse(
          streamOf([
            [..._payload.sublist(range.start, range.end + 1), 0xff],
          ]),
          HttpStatus.partialContent,
        );
      });

      final result = await run(
        downloader(client, maxChunkRetries: 0),
        'long-chunk.bin',
        workers: 1,
      );

      expect(
        result.outcome,
        failedWith(
          isA<DownloadTruncated>()
              .having((it) => it.expectedBytes, 'expectedBytes', 10)
              .having((it) => it.receivedBytes, 'receivedBytes', 11),
        ),
      );
      expect(receivedPerChunk('long-chunk.bin'), [0, 0, 0, 0]);
    });
  });

  group('ChunkedFileDownloader stalls', () {
    const idle = Duration(seconds: 10);

    test('retries a response that sends nothing for the idle timeout', () {
      fakeAsync((async) {
        var requests = 0;
        final client = MockClient.streaming((request, _) async {
          if (requests++ == 0) {
            return http.StreamedResponse(
              StreamController<List<int>>().stream,
              HttpStatus.partialContent,
            );
          }
          return partialResponse(_payload, RequestedRange(request));
        });
        FileOutcome? outcome;
        unawaited(
          run(
            downloader(client, idleTimeout: idle),
            'idle-body.bin',
            workers: 1,
          ).then((result) => outcome = result.outcome),
        );

        async.elapse(idle - const Duration(seconds: 1));
        expect(outcome, isNull);
        async.elapse(const Duration(seconds: 2));

        expect(outcome, isA<FileDownloaded>());
        expectDownloaded('idle-body.bin');
      });
    });

    test('retries a request that gets no response for the idle timeout', () {
      fakeAsync((async) {
        var requests = 0;
        final client = MockClient.streaming((request, _) {
          if (requests++ == 0) return Completer<http.StreamedResponse>().future;
          return Future.value(
            partialResponse(_payload, RequestedRange(request)),
          );
        });
        FileOutcome? outcome;
        unawaited(
          run(
            downloader(client, idleTimeout: idle),
            'idle-send.bin',
            workers: 1,
          ).then((result) => outcome = result.outcome),
        );

        async.elapse(idle + const Duration(seconds: 1));

        expect(outcome, isA<FileDownloaded>());
      });
    });

    test('fails as a network error once every retry stalls', () {
      fakeAsync((async) {
        final client = MockClient.streaming(
          (_, _) async => http.StreamedResponse(
            StreamController<List<int>>().stream,
            HttpStatus.partialContent,
          ),
        );
        FileOutcome? outcome;
        unawaited(
          run(
            downloader(client, idleTimeout: idle, maxChunkRetries: 1),
            'idle-exhaust.bin',
            workers: 1,
          ).then((result) => outcome = result.outcome),
        );

        async.elapse(idle * 3);

        expect(outcome, failedWith(isA<DownloadNetworkError>()));
        expectResumable('idle-exhaust.bin');
      });
    });

    test('settles promptly when cancelled on a stalled socket', () {
      fakeAsync((async) {
        final cancellation = IsolateCancellationTokenSource();
        final stalled = StreamController<List<int>>();
        final requests = <http.BaseRequest>[];
        final client = MockClient.streaming((request, _) async {
          requests.add(request);
          return http.StreamedResponse(
            stalled.stream,
            HttpStatus.partialContent,
          );
        });
        FileOutcome? outcome;
        unawaited(
          run(
            downloader(client, chunkSizeBytes: 40, writeBufferBytes: 4),
            'cancel-stalled.bin',
            workers: 1,
            cancellation: cancellation.token,
          ).then((result) => outcome = result.outcome),
        );
        async.elapse(Duration.zero);
        stalled.add(_payload.sublist(0, 8));
        async.elapse(const Duration(seconds: 1));
        expect(outcome, isNull);
        var aborted = false;
        unawaited(
          (requests.single as http.Abortable).abortTrigger!.then(
            (_) => aborted = true,
          ),
        );

        cancellation.cancel();
        async.elapse(Duration.zero);

        expect(outcome, isA<FileCancelled>());
        expect(aborted, isTrue);
        expect(stalled.hasListener, isFalse);
        expect(receivedPerChunk('cancel-stalled.bin'), [8]);
      });
    });

    test('settles promptly when cancelled while awaiting a response', () {
      fakeAsync((async) {
        final cancellation = IsolateCancellationTokenSource();
        final client = MockClient.streaming(
          (_, _) => Completer<http.StreamedResponse>().future,
        );
        FileOutcome? outcome;
        unawaited(
          run(
            downloader(client),
            'cancel-connecting.bin',
            cancellation: cancellation.token,
          ).then((result) => outcome = result.outcome),
        );
        async.elapse(const Duration(seconds: 1));

        cancellation.cancel();
        async.elapse(Duration.zero);

        expect(outcome, isA<FileCancelled>());
        expectResumable('cancel-connecting.bin');
      });
    });

    test('stops waiting out a retry delay when cancelled', () {
      fakeAsync((async) {
        final cancellation = IsolateCancellationTokenSource();
        final client = MockClient.streaming(
          (request, _) async => RequestedRange(request).start == 0
              ? partialResponse(_payload, RequestedRange(request))
              : http.StreamedResponse(
                  const Stream.empty(),
                  HttpStatus.serviceUnavailable,
                ),
        );
        final engine = ChunkedFileDownloader(
          fileSystem: fileSystem,
          client: client,
          chunkSizeBytes: 10,
          retryBaseDelay: const Duration(minutes: 1),
        );
        FileOutcome? outcome;
        unawaited(
          collect(
            engine.download(
              url: 'https://example.com/cancel-backoff.bin',
              targetPath: target('cancel-backoff.bin'),
              expectedBytes: 40,
              workers: 2,
              cancellation: cancellation.token,
            ),
          ).then((result) => outcome = result.outcome),
        );
        async.elapse(const Duration(seconds: 1));

        cancellation.cancel();
        async.elapse(Duration.zero);

        expect(outcome, isA<FileCancelled>());
      });
    });
  });

  group('ChunkedFileDownloader disk errors', () {
    _MockHasher throwingHasher(
      FileSystemException error, {
      void Function()? before,
    }) {
      final hasher = _MockHasher();
      when(
        () => hasher.sha256Of(
          any(),
          cancellation: any(named: 'cancellation'),
        ),
      ).thenAnswer((_) async {
        before?.call();
        throw error;
      });
      return hasher;
    }

    test('reports a full disk', () async {
      final result = await run(
        downloader(
          rangeServingClient(_payload),
          hasher: throwingHasher(
            const FileSystemException(
              'Write failed',
              '/models/full.bin.part',
              OSError('No space left on device', 28),
            ),
          ),
        ),
        'full.bin',
        expectedSha256: _correctHash,
      );

      expect(result.outcome, failedWith(isA<DownloadDiskFull>()));
      expectResumable('full.bin');
      expect(receivedPerChunk('full.bin'), [10, 10, 10, 10]);
    });

    test('reports any other file system error as an io error', () async {
      final result = await run(
        downloader(
          rangeServingClient(_payload),
          hasher: throwingHasher(
            const FileSystemException(
              'Read failed',
              '/models/io.bin.part',
              OSError('Permission denied', 13),
            ),
          ),
        ),
        'io.bin',
        expectedSha256: _correctHash,
      );

      expect(
        result.outcome,
        failedWith(
          isA<DownloadIoError>().having(
            (it) => it.detail,
            'detail',
            contains('Permission denied'),
          ),
        ),
      );
    });

    test(
      'keeps the last manifest when the final one cannot be written',
      () async {
        final metaPath = '${target('stuck.bin')}.part.meta';

        final result = await run(
          downloader(
            rangeServingClient(_payload),
            hasher: throwingHasher(
              const FileSystemException('Read failed'),
              before: () {
                file(metaPath).deleteSync();
                fileSystem.directory(metaPath).createSync();
              },
            ),
          ),
          'stuck.bin',
          expectedSha256: _correctHash,
        );

        expect(result.outcome, failedWith(isA<DownloadIoError>()));
        expect(fileSystem.directory(metaPath).existsSync(), isTrue);
      },
    );
  });

  group('ChunkedFileDownloader verification', () {
    test('accepts a matching sha256, ignoring case', () async {
      final result = await run(
        downloader(rangeServingClient(_payload)),
        'verified.bin',
        expectedSha256: _correctHash.toUpperCase(),
      );

      expect(result.outcome, isA<FileDownloaded>());
      expectDownloaded('verified.bin');
    });

    test('reports a mismatch and deletes the bytes', () async {
      final result = await run(
        downloader(rangeServingClient(_payload)),
        'mismatch.bin',
        expectedSha256: _wrongHash,
      );

      expect(
        result.outcome,
        isA<FileChecksumMismatch>()
            .having((outcome) => outcome.expected, 'expected', _wrongHash)
            .having((outcome) => outcome.actual, 'actual', _correctHash),
      );
      for (final suffix in ['', '.part', '.part.meta']) {
        expect(file('${target('mismatch.bin')}$suffix').existsSync(), isFalse);
      }
    });

    test('skips verification without an expected sha256', () async {
      final result = await run(
        downloader(rangeServingClient(_payload)),
        'unverified.bin',
      );

      expect(result.events.whereType<FileVerifying>(), isEmpty);
      expectDownloaded('unverified.bin');
    });

    test('verifies a download whose chunks were all done already', () async {
      final targetPath = target('already-done.bin');
      void seed() {
        seedPart(targetPath, _payload);
        seedManifest(
          targetPath,
          url: 'https://example.com/already-done.bin',
          chunks: const [
            [0, 19, 20],
            [20, 39, 20],
          ],
        );
      }

      final engine = downloader(
        MockClient((_) => fail('no request when every chunk is done')),
        chunkSizeBytes: 20,
      );

      seed();
      final wrong = await run(
        engine,
        'already-done.bin',
        expectedSha256: _wrongHash,
      );
      seed();
      final right = await run(
        engine,
        'already-done.bin',
        expectedSha256: _correctHash,
      );

      expect(wrong.outcome, isA<FileChecksumMismatch>());
      expect(right.outcome, isA<FileDownloaded>());
      expectDownloaded('already-done.bin');
    });

    test('reports verifying once, after every byte arrived', () async {
      final result = await run(
        downloader(rangeServingClient(_payload)),
        'event-order.bin',
        expectedSha256: _correctHash,
      );

      final verifying = [
        for (var index = 0; index < result.events.length; index++)
          if (result.events[index] is FileVerifying) index,
      ];
      expect(verifying, hasLength(1));
      final before = result.events.sublist(0, verifying.single);
      expect((before.last as FileBytesReceived).cumulative, 40);
      expect((result.events.last as FileBytesReceived).cumulative, 40);
    });

    test('hashes the .part file exactly once', () async {
      final hasher = _MockHasher();
      when(
        () => hasher.sha256Of(
          any(),
          cancellation: any(named: 'cancellation'),
        ),
      ).thenAnswer((_) async => const FileHashed(_correctHash));

      await run(
        downloader(rangeServingClient(_payload), hasher: hasher),
        'hasher-call.bin',
        expectedSha256: _correctHash,
      );

      final hashed =
          verify(
                () => hasher.sha256Of(
                  captureAny(),
                  cancellation: any(named: 'cancellation'),
                ),
              ).captured.single
              as File;
      expect(hashed.path, '${target('hasher-call.bin')}.part');
    });
  });

  test('close closes the http client', () {
    final client = _MockHttpClient();

    downloader(client).close();

    verify(client.close).called(1);
  });

  group('FileHasher', () {
    test('digests a file', () async {
      final payloadFile = file('/payload.bin')..writeAsBytesSync(_payload);

      expect(
        await const FileHasher().sha256Of(
          payloadFile,
          cancellation: const NeverCancelledIsolateCancellationToken(),
        ),
        isA<FileHashed>().having(
          (hashed) => hashed.digest,
          'digest',
          _correctHash,
        ),
      );
    });

    test('stops reading at the next chunk once cancelled', () async {
      final cancellation = IsolateCancellationTokenSource();
      var stoppedReading = false;
      final chunks = StreamController<List<int>>(
        onCancel: () => stoppedReading = true,
      );
      final bigFile = _MockFile();
      when(bigFile.openRead).thenAnswer((_) => chunks.stream);

      final hashing = const FileHasher().sha256Of(
        bigFile,
        cancellation: cancellation.token,
      );
      chunks.add(_payload);
      await pumpEventQueue();
      cancellation.cancel();
      chunks.add(_payload);

      expect(await hashing, isA<FileHashCancelled>());
      expect(stoppedReading, isTrue);
    });
  });
}
