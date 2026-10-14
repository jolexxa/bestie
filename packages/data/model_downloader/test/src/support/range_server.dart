import 'dart:async';
import 'dart:io' show HttpStatus;

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:model_downloader/src/file_transfer.dart';

/// Emits [chunks] in order, optionally delayed, then an optional error.
Stream<List<int>> streamOf(
  List<List<int>> chunks, {
  List<Duration> delays = const [],
  void Function()? onFirstChunk,
  Object? error,
}) {
  final controller = StreamController<List<int>>();
  unawaited(() async {
    for (var index = 0; index < chunks.length; index++) {
      if (index == 0) onFirstChunk?.call();
      if (index < delays.length) await Future<void>.delayed(delays[index]);
      controller.add(chunks[index]);
    }
    if (error != null) controller.addError(error);
    await controller.close();
  }());
  return controller.stream;
}

/// The inclusive byte range a request asks for.
class RequestedRange {
  RequestedRange(http.BaseRequest request) {
    final match = RegExp(
      r'bytes=(\d+)-(\d+)',
    ).firstMatch(request.headers['Range']!)!;
    start = int.parse(match.group(1)!);
    end = int.parse(match.group(2)!);
  }

  late final int start;
  late final int end;

  String get header => 'bytes=$start-$end';
}

http.StreamedResponse partialResponse(
  List<int> payload,
  RequestedRange range, {
  List<Duration> delays = const [],
  void Function()? onFirstChunk,
}) => http.StreamedResponse(
  streamOf(
    [payload.sublist(range.start, range.end + 1)],
    delays: delays,
    onFirstChunk: onFirstChunk,
  ),
  HttpStatus.partialContent,
  contentLength: range.end - range.start + 1,
);

/// Serves slices of [payload] for every Range request.
MockClient rangeServingClient(List<int> payload) => MockClient.streaming(
  (request, _) async => partialResponse(payload, RequestedRange(request)),
);

/// Progress events and the outcome of one transfer.
class CollectedTransfer {
  CollectedTransfer(this.events, this.outcome);

  final List<FileProgress> events;
  final FileOutcome outcome;

  List<int> get bytes => [
    for (final event in events)
      if (event is FileBytesReceived) event.cumulative,
  ];
}

Future<CollectedTransfer> collect(FileTransfer transfer) async {
  final events = <FileProgress>[];
  final delivered = transfer.progress.listen(events.add).asFuture<void>();
  final outcome = await transfer.outcome;
  await delivered;
  return CollectedTransfer(events, outcome);
}
