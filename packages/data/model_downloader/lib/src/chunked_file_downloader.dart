import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io' show FileMode, FileSystemException, HttpStatus;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:file/file.dart';
import 'package:http/http.dart' as http;
import 'package:intentions/intentions.dart';
import 'package:isolate_worker/isolate_worker.dart';
import 'package:model_downloader/src/download_failure.dart';
import 'package:model_downloader/src/file_hasher.dart';
import 'package:model_downloader/src/file_transfer.dart';
import 'package:model_downloader/src/model_downloader.dart';

/// Downloads one file as fixed-size chunks served by a pool of parallel HTTP
/// Range requests, resuming from `<target>.part` and its `<target>.part.meta`
/// manifest when an earlier attempt left them behind.
///
/// The chunk queue and worker pool follow the design of `range_request`'s
/// `ChunkFetcher` (BSD-3-Clause, Kyohei Ito).
@PartOf(ModelDownloader)
class ChunkedFileDownloader {
  /// [manifestFlushBytes] should stay below [chunkSizeBytes] so a large
  /// chunk records its progress before it finishes. A response that sends
  /// nothing for [idleTimeout] is abandoned and retried.
  ChunkedFileDownloader({
    required FileSystem fileSystem,
    required http.Client client,
    FileHasher hasher = const FileHasher(),
    int chunkSizeBytes = 16 * 1024 * 1024,
    int manifestFlushBytes = 8 * 1024 * 1024,
    int writeBufferBytes = 4 * 1024 * 1024,
    int maxChunkRetries = 5,
    Duration retryBaseDelay = const Duration(milliseconds: 500),
    Duration idleTimeout = const Duration(seconds: 30),
  }) : _fileSystem = fileSystem,
       _client = client,
       _hasher = hasher,
       _chunkSizeBytes = chunkSizeBytes,
       _manifestFlushBytes = manifestFlushBytes,
       _writeBufferBytes = writeBufferBytes,
       _maxChunkRetries = maxChunkRetries,
       _retryBaseDelay = retryBaseDelay,
       _idleTimeout = idleTimeout;

  static const _maxRetryDelay = Duration(seconds: 8);

  /// ENOSPC on POSIX and ERROR_DISK_FULL on Windows.
  static const _noSpaceErrorCodes = {28, 112};

  final FileSystem _fileSystem;
  final http.Client _client;
  final FileHasher _hasher;
  final int _chunkSizeBytes;
  final int _manifestFlushBytes;
  final int _writeBufferBytes;
  final int _maxChunkRetries;
  final Duration _retryBaseDelay;
  final Duration _idleTimeout;

  /// Starts downloading [url] to [targetPath] with up to [workers] parallel
  /// requests. An existing [targetPath] of the expected size and sha256
  /// counts as already downloaded; any other is replaced.
  FileTransfer download({
    required String url,
    required String targetPath,
    required int expectedBytes,
    String? expectedSha256,
    int workers = 8,
    IsolateCancellationToken cancellation =
        const NeverCancelledIsolateCancellationToken(),
  }) {
    final session = _FileSession(
      uri: Uri.parse(url),
      targetPath: targetPath,
      expectedBytes: expectedBytes,
      expectedSha256: expectedSha256,
      workers: workers,
      cancellation: cancellation,
    );
    return FileTransfer(
      progress: session.progress.stream,
      outcome: _settle(session),
    );
  }

  void close() => _client.close();

  Future<FileOutcome> _settle(_FileSession session) async {
    try {
      return await _download(session);
    } on Exception catch (error) {
      _saveProgress(session);
      return switch (error) {
        _Cancelled() => const FileCancelled(),
        _ when session.isCancelled => const FileCancelled(),
        _ => FileFailed(_failureFor(error)),
      };
    } finally {
      session.stop();
      unawaited(session.progress.close());
    }
  }

  DownloadFailure _failureFor(Exception error) => switch (error) {
    _Failure(:final failure) => failure,
    FileSystemException(:final osError?)
        when _noSpaceErrorCodes.contains(osError.errorCode) =>
      const DownloadDiskFull(),
    FileSystemException() => DownloadIoError('$error'),
    _ => DownloadNetworkError('$error'),
  };

  Future<FileOutcome> _download(_FileSession session) async {
    if (await _isAlreadyDownloaded(session)) {
      session
        ..received = session.expectedBytes
        ..kept = session.expectedBytes
        ..report();
      return const FileDownloaded();
    }

    final chunks = _chunksFor(session.expectedBytes);
    final manifest = session.manifest =
        _resume(session, chunks) ?? _start(session, chunks);
    session
      ..throwIfCancelled()
      ..received = manifest.received
      ..kept = manifest.received
      ..report();

    final incomplete = Queue.of(
      manifest.chunks.where((chunk) => !chunk.isComplete),
    );
    if (incomplete.isEmpty) return _finalize(session);

    final probe = incomplete.removeFirst();
    final probeOffset = probe.resumeOffset;
    final probeResponse = await _retrying(session, () async {
      final response = await _send(session, probeOffset, probe.end);
      if (response.statusCode != HttpStatus.ok) {
        _requirePartialContent(response);
      }
      return response;
    });
    if (probeResponse.statusCode == HttpStatus.ok) {
      session.manifest = null;
      _deleteIfExists(session.metaPath);
      return _drainFullResponse(session, probeResponse);
    }

    await Future.wait([
      _probeWorker(session, incomplete, probe, probeResponse, probeOffset),
      for (var worker = 1; worker < session.workers; worker++)
        _runWorker(session, incomplete),
    ], eagerError: true);
    session.throwIfCancelled();
    return _finalize(session);
  }

  /// Whether the target already holds the expected bytes. A target that
  /// does not is deleted so it can be downloaded again.
  Future<bool> _isAlreadyDownloaded(_FileSession session) async {
    final target = _fileSystem.file(session.targetPath);
    if (!target.existsSync()) return false;
    final intact =
        target.lengthSync() == session.expectedBytes &&
        await _checksumMismatchOf(session, target) == null;
    if (!intact) target.deleteSync();
    return intact;
  }

  /// Drains the probe's response as the first worker. A probe that stalls
  /// falls back to the retrying chunk path, which resumes from the last
  /// byte written to disk.
  Future<void> _probeWorker(
    _FileSession session,
    Queue<_Chunk> pending,
    _Chunk probe,
    http.StreamedResponse response,
    int offset,
  ) async {
    try {
      await _drainChunk(session, probe, response, offset);
    } on _Cancelled {
      rethrow;
    } on Exception {
      await _downloadChunk(session, probe);
    }
    await _runWorker(session, pending);
  }

  Future<void> _runWorker(_FileSession session, Queue<_Chunk> pending) async {
    while (!session.isStopped && pending.isNotEmpty) {
      await _downloadChunk(session, pending.removeFirst());
    }
  }

  Future<void> _downloadChunk(_FileSession session, _Chunk chunk) =>
      _retrying(session, () async {
        if (session.isStopped) return;
        final offset = chunk.resumeOffset;
        final response = await _send(session, offset, chunk.end);
        _requirePartialContent(response);
        await _drainChunk(session, chunk, response, offset);
      });

  /// Runs [attempt] until it succeeds, backing off between tries. Gives up
  /// on cancellation, once the session stops, when the retry budget is spent,
  /// or on an error that a retry cannot fix.
  Future<T> _retrying<T>(
    _FileSession session,
    Future<T> Function() attempt,
  ) async {
    for (var tries = 0; ; tries++) {
      session.throwIfCancelled();
      try {
        return await attempt();
      } on _Cancelled {
        rethrow;
      } on Exception catch (error, stackTrace) {
        if (tries >= _maxChunkRetries ||
            session.isStopped ||
            !_isRetryable(error)) {
          Error.throwWithStackTrace(error, stackTrace);
        }
        await Future.any([
          Future<void>.delayed(_retryDelay(tries)),
          session.stopped,
        ]);
      }
    }
  }

  /// Server errors, timeouts, rate limits and dropped connections may pass;
  /// any other status means the request itself is wrong.
  static bool _isRetryable(Exception error) => switch (error) {
    _Failure(failure: DownloadHttpStatus(:final statusCode)) =>
      statusCode >= HttpStatus.internalServerError ||
          statusCode == HttpStatus.requestTimeout ||
          statusCode == HttpStatus.tooManyRequests,
    _ => true,
  };

  Duration _retryDelay(int attempt) => Duration(
    milliseconds: math.min(
      _retryBaseDelay.inMilliseconds * (1 << attempt),
      _maxRetryDelay.inMilliseconds,
    ),
  );

  /// Sends a Range request that is aborted when the session stops and gives
  /// up when no response arrives within the idle timeout.
  Future<http.StreamedResponse> _send(
    _FileSession session,
    int start,
    int end,
  ) {
    final request = http.AbortableRequest(
      'GET',
      session.uri,
      abortTrigger: session.stopped,
    )..headers['Range'] = 'bytes=$start-$end';
    return Future.any([
      _client.send(request).timeout(_idleTimeout),
      session.stopped.then((_) => throw const _Cancelled()),
    ]);
  }

  void _requirePartialContent(http.StreamedResponse response) {
    if (response.statusCode == HttpStatus.partialContent) return;
    unawaited(response.stream.listen(null).cancel());
    throw _Failure(DownloadHttpStatus(response.statusCode));
  }

  /// [body] failing with a [TimeoutException] when no packet arrives for
  /// the idle timeout, and with [_Cancelled] as soon as the session stops.
  Stream<List<int>> _watched(_FileSession session, Stream<List<int>> body) =>
      Stream.multi((controller) {
        late final StreamSubscription<List<int>> subscription;
        late Timer idle;

        void end(Object error) {
          idle.cancel();
          unawaited(subscription.cancel());
          controller
            ..addErrorSync(error)
            ..closeSync();
        }

        Timer startIdle() => Timer(
          _idleTimeout,
          () => end(TimeoutException('No data received', _idleTimeout)),
        );

        idle = startIdle();
        subscription = body.listen(
          (bytes) {
            idle.cancel();
            idle = startIdle();
            controller.addSync(bytes);
          },
          onError: controller.addErrorSync,
          onDone: () {
            idle.cancel();
            controller.closeSync();
          },
        );
        controller.onCancel = () {
          idle.cancel();
          unawaited(subscription.cancel());
          return Future<void>.value();
        };
        unawaited(
          session.stopped.then((_) {
            if (!controller.isClosed) end(const _Cancelled());
          }),
        );
      });

  /// Writes a 206 body into the chunk's slice of the `.part` file. Progress
  /// counts bytes as they arrive; disk writes are coalesced, and bytes that
  /// never reached disk are taken back out of progress if the stream fails.
  /// A body shorter or longer than the requested range is a failure.
  Future<void> _drainChunk(
    _FileSession session,
    _Chunk chunk,
    http.StreamedResponse response,
    int offset,
  ) async {
    // Append mode keeps the other chunks' bytes; write mode would truncate.
    final file = _fileSystem
        .file(session.tempPath)
        .openSync(mode: FileMode.append);
    final buffer = BytesBuilder(copy: false);
    final durableAtStart = chunk.received;
    final requested = chunk.end - offset + 1;
    var counted = 0;
    var sinceManifestWrite = 0;

    Future<void> flush() async {
      if (buffer.isEmpty) return;
      final data = buffer.takeBytes();
      await file.writeFrom(data);
      chunk.received += data.length;
      sinceManifestWrite += data.length;
      if (sinceManifestWrite >= _manifestFlushBytes) {
        _writeManifest(session);
        sinceManifestWrite = 0;
      }
    }

    _Failure truncated() => _Failure(
      DownloadTruncated(expectedBytes: requested, receivedBytes: counted),
    );

    try {
      await file.setPosition(offset);
      await for (final bytes in _watched(session, response.stream)) {
        session
          ..received += bytes.length
          ..report();
        counted += bytes.length;
        if (counted > requested) throw truncated();
        buffer.add(bytes);
        if (buffer.length >= _writeBufferBytes) await flush();
      }
      await flush();
      if (counted < requested) throw truncated();
      _writeManifest(session);
    } on Exception {
      session.received -= counted - (chunk.received - durableAtStart);
      rethrow;
    } finally {
      await file.close();
    }
  }

  /// The server ignored the Range header and is sending the whole file.
  Future<FileOutcome> _drainFullResponse(
    _FileSession session,
    http.StreamedResponse response,
  ) async {
    final sink = _fileSystem.file(session.tempPath).openWrite();
    session
      ..received = 0
      ..kept = 0;
    try {
      await for (final bytes in _watched(session, response.stream)) {
        sink.add(bytes);
        session
          ..received += bytes.length
          ..report();
      }
    } finally {
      await sink.close();
    }
    if (session.received != session.expectedBytes) {
      throw _Failure(
        DownloadTruncated(
          expectedBytes: session.expectedBytes,
          receivedBytes: session.received,
        ),
      );
    }
    return _finalize(session);
  }

  /// Verifies the sha256 when one is expected, then moves `.part` into
  /// place.
  Future<FileOutcome> _finalize(_FileSession session) async {
    final partFile = _fileSystem.file(session.tempPath);
    if (await _checksumMismatchOf(session, partFile) case final mismatch?) {
      _deleteIfExists(session.tempPath);
      _deleteIfExists(session.metaPath);
      return mismatch;
    }
    await partFile.rename(session.targetPath);
    _deleteIfExists(session.metaPath);
    session
      ..received = session.expectedBytes
      ..report();
    return const FileDownloaded();
  }

  /// The mismatch between [file] and the expected sha256, or null when they
  /// agree or no sha256 is expected.
  Future<FileChecksumMismatch?> _checksumMismatchOf(
    _FileSession session,
    File file,
  ) async {
    final expected = session.expectedSha256?.toLowerCase();
    if (expected == null) return null;
    session.reportVerifying();
    switch (await _hasher.sha256Of(file, cancellation: session.cancellation)) {
      case FileHashCancelled():
        throw const _Cancelled();
      case FileHashed(digest: final actual):
        return actual == expected
            ? null
            : FileChecksumMismatch(expected: expected, actual: actual);
    }
  }

  /// The manifest left by an earlier attempt at this exact request, or null
  /// after clearing away anything stale.
  _Manifest? _resume(_FileSession session, List<_Chunk> chunks) {
    _deleteIfExists(session.manifestTempPath);
    final partFile = _fileSystem.file(session.tempPath);
    final manifest = _readManifest(session);
    if (manifest != null &&
        manifest.matches(session.uri, session.expectedBytes, chunks) &&
        partFile.existsSync() &&
        partFile.lengthSync() == session.expectedBytes) {
      return manifest;
    }
    _deleteIfExists(session.tempPath);
    _deleteIfExists(session.metaPath);
    return null;
  }

  _Manifest? _readManifest(_FileSession session) {
    try {
      final json = jsonDecode(
        _fileSystem.file(session.metaPath).readAsStringSync(),
      );
      return _Manifest.fromJson(json! as Map<String, Object?>);
    } on Object {
      return null;
    }
  }

  _Manifest _start(_FileSession session, List<_Chunk> chunks) {
    final manifest = session.manifest = _Manifest(
      url: session.uri.toString(),
      totalBytes: session.expectedBytes,
      chunks: chunks,
    );
    _fileSystem.file(session.tempPath).createSync(recursive: true);
    _fileSystem.file(session.tempPath).openSync(mode: FileMode.write)
      ..truncateSync(session.expectedBytes)
      ..closeSync();
    _writeManifest(session);
    return manifest;
  }

  /// Records how far the chunks got so a later attempt resumes from there.
  /// A manifest that cannot be written leaves the previous one in place.
  void _saveProgress(_FileSession session) {
    try {
      _writeManifest(session);
    } on FileSystemException {
      return;
    }
  }

  /// Writes beside the manifest, then renames over it, so a crash never
  /// leaves a half-written manifest behind.
  void _writeManifest(_FileSession session) {
    final manifest = session.manifest;
    if (manifest == null) return;
    _fileSystem.file(session.manifestTempPath)
      ..writeAsStringSync(jsonEncode(manifest.toJson()))
      ..renameSync(session.metaPath);
  }

  void _deleteIfExists(String path) {
    final file = _fileSystem.file(path);
    if (file.existsSync()) file.deleteSync();
  }

  List<_Chunk> _chunksFor(int totalBytes) {
    final count = (totalBytes + _chunkSizeBytes - 1) ~/ _chunkSizeBytes;
    return [
      for (var index = 0; index < count; index++)
        _Chunk(
          start: index * _chunkSizeBytes,
          end: math.min((index + 1) * _chunkSizeBytes, totalBytes) - 1,
        ),
    ];
  }
}

/// Everything one file download shares across its workers.
class _FileSession {
  _FileSession({
    required this.uri,
    required this.targetPath,
    required this.expectedBytes,
    required this.expectedSha256,
    required this.workers,
    required this.cancellation,
  }) {
    unawaited(cancellation.cancelled.then((_) => stop()));
  }

  final Uri uri;
  final String targetPath;
  final int expectedBytes;
  final String? expectedSha256;
  final int workers;
  final IsolateCancellationToken cancellation;
  final progress = StreamController<FileProgress>(sync: true);
  final _stopped = Completer<void>();

  /// The chunk layout being resumed into, or null when no resume is
  /// possible.
  _Manifest? manifest;

  /// Bytes received off the wire, ahead of what has reached disk.
  int received = 0;

  /// The part of [received] that was already on disk before this attempt.
  int kept = 0;

  String get tempPath => '$targetPath.part';
  String get metaPath => '$targetPath.part.meta';
  String get manifestTempPath => '$metaPath.tmp';

  /// Completes once the download is cancelled or has an outcome, so
  /// in-flight requests are abandoned and stray workers stop.
  Future<void> get stopped => _stopped.future;

  bool get isStopped => _stopped.isCompleted;

  bool get isCancelled => cancellation.isCancellationRequested;

  void stop() {
    if (!_stopped.isCompleted) _stopped.complete();
  }

  void throwIfCancelled() {
    if (!isCancelled) return;
    stop();
    throw const _Cancelled();
  }

  void report() => _emit(FileBytesReceived(received, keptBytes: kept));

  void reportVerifying() => _emit(const FileVerifying());

  void _emit(FileProgress event) {
    if (!progress.isClosed) progress.add(event);
  }
}

class _Cancelled implements Exception {
  const _Cancelled();
}

class _Failure implements Exception {
  const _Failure(this.failure);

  final DownloadFailure failure;
}

class _Chunk {
  _Chunk({
    required this.start,
    required this.end,
    this.received = 0,
  });

  final int start;
  final int end;

  /// Bytes of this chunk durably written to the `.part` file.
  int received;

  int get length => end - start + 1;

  int get resumeOffset => start + received;

  bool get isComplete => received == length;

  Map<String, Object?> toJson() => {
    'start': start,
    'end': end,
    'received': received,
  };
}

class _Manifest {
  _Manifest({
    required this.url,
    required this.totalBytes,
    required this.chunks,
  });

  factory _Manifest.fromJson(Map<String, Object?> json) {
    final version = json['version'];
    if (version != currentVersion) {
      throw FormatException('Unknown manifest version: $version');
    }
    final chunks = json['chunks']! as List<Object?>;
    return _Manifest(
      url: json['url']! as String,
      totalBytes: json['totalBytes']! as int,
      chunks: [
        for (final chunk in chunks)
          _chunkFromJson(chunk! as Map<String, Object?>),
      ],
    );
  }

  static const currentVersion = 1;

  final String url;
  final int totalBytes;
  final List<_Chunk> chunks;

  int get received => chunks.fold(0, (sum, chunk) => sum + chunk.received);

  bool matches(Uri uri, int expectedBytes, List<_Chunk> expectedChunks) =>
      url == uri.toString() &&
      totalBytes == expectedBytes &&
      chunks.length == expectedChunks.length &&
      [
        for (var index = 0; index < chunks.length; index++)
          chunks[index].start == expectedChunks[index].start &&
              chunks[index].end == expectedChunks[index].end &&
              chunks[index].received >= 0 &&
              chunks[index].received <= chunks[index].length,
      ].every((same) => same);

  Map<String, Object?> toJson() => {
    'version': currentVersion,
    'url': url,
    'totalBytes': totalBytes,
    'chunks': [for (final chunk in chunks) chunk.toJson()],
  };

  static _Chunk _chunkFromJson(Map<String, Object?> json) => _Chunk(
    start: json['start']! as int,
    end: json['end']! as int,
    received: json['received']! as int,
  );
}
