@Tags(['integration'])
library;

import 'dart:io';

import 'package:gguf_reader/gguf_reader.dart';
import 'package:test/test.dart';

/// Reads every GGUF in `$BESTIE_GGUF_DIR` (default `~/Dropbox/AI/models`).
/// Run with `dart test --run-skipped -t integration`.
void main() {
  final home = Platform.environment['HOME'] ?? '';
  final directory = Directory(
    Platform.environment['BESTIE_GGUF_DIR'] ?? '$home/Dropbox/AI/models',
  );
  final models = directory.existsSync()
      ? directory
            .listSync()
            .whereType<File>()
            .where((file) => file.path.endsWith('.gguf'))
            .toList()
      : <File>[];

  test(
    'reads real model headers',
    skip: 'Reads local model files; run with --run-skipped.',
    () {
      expect(models, isNotEmpty, reason: 'No GGUFs in ${directory.path}');
      const reader = GgufReader();
      for (final model in models) {
        final result = reader.read(model.path);
        expect(result, isA<GgufRead>(), reason: model.path);
        final header = (result as GgufRead).header;
        expect(header.architecture, isNotNull, reason: model.path);
        expect(header.contextLength, isNotNull, reason: model.path);
        expect(header.parameterCount, greaterThan(0), reason: model.path);
        expect(
          header.tensorDataOffset,
          lessThan(model.lengthSync()),
          reason: model.path,
        );
        stdout.writeln(
          '${model.uri.pathSegments.last}: ${header.architecture} '
          'ctx=${header.contextLength} params=${header.parameterCount} '
          'ftype=${header.fileType} header=${header.headerByteLength}B',
        );
      }
    },
  );
}
