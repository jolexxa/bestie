# isolate_worker

[![style: very good analysis][very_good_analysis_badge]][very_good_analysis_link]

A small Dart package for long-lived worker isolates.

It wraps the robust ports pattern with typed codecs, request IDs, pending-request tracking, explicit shutdown, and sealed result types.

The shape is based on Dart's [robust ports example][robust_ports_example], but the API returns operation results instead of throwing remote errors.

You'll need to BYOB — Bring Your Own Binary (Serializer).

## Usage

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:isolate_worker/isolate_worker.dart';

final class StringMessageCodec implements IsolateMessageCodec<String> {
  const StringMessageCodec();

  @override
  Uint8List encode(String message) {
    return Uint8List.fromList(utf8.encode(message));
  }

  @override
  String decode(Uint8List bytes) {
    return utf8.decode(bytes);
  }
}

Future<void> main() async {
  final spawnResult = await IsolateWorker.spawn<String, String>(
    requestCodec: const StringMessageCodec(),
    responseCodec: const StringMessageCodec(),
    commandHandler: (request) => request.toUpperCase(),
  );

  final worker = switch (spawnResult) {
    IsolateSpawnSucceeded(:final worker) => worker,
    IsolateSpawnFailed(:final message) => throw StateError(message),
  };

  try {
    final response = await worker.send('cow');

    switch (response) {
      case IsolateSucceeded(:final value):
        print(value); // COW
      case IsolateFailed(:final message):
        print(message);
    }
  } finally {
    worker.close();
  }
}
```

Run the tests from this package:

```sh
dart test test/src/isolate_worker_test.dart
```

[robust_ports_example]: https://dart.dev/language/isolates#robust-ports-example
[very_good_analysis_badge]: https://img.shields.io/badge/style-very_good_analysis-B22C89.svg
[very_good_analysis_link]: https://pub.dev/packages/very_good_analysis
