import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:vt_parser/vt_parser.dart';

import '_collector.dart';

/// Decode a golden event blob back into `ParserEvent`s so we can
/// assert equality against a fresh parse.
ParserEvent _decodeEvent(Map<String, Object?> json) {
  switch (json['type']! as String) {
    case 'print':
      return PrintEvent(json['char']! as int);
    case 'execute':
      return ExecuteEvent(json['byte']! as int);
    case 'esc':
      return EscDispatchEvent(
        intermediates: (json['intermediates']! as List).cast<int>(),
        finalByte: json['finalByte']! as int,
        ignore: json['ignore']! as bool,
      );
    case 'csi':
      final rawParams = (json['params']! as List).cast<List<dynamic>>();
      return CsiDispatchEvent(
        params: rawParams.map((p) => p.cast<int>()).toList(),
        intermediates: (json['intermediates']! as List).cast<int>(),
        finalByte: json['finalByte']! as int,
        ignore: json['ignore']! as bool,
      );
    case 'osc':
      final rawParams = (json['params']! as List).cast<List<dynamic>>();
      return OscDispatchEvent(
        params: rawParams.map((p) => p.cast<int>()).toList(),
        bellTerminated: json['bellTerminated']! as bool,
      );
    case 'dcsHook':
      final rawParams = (json['params']! as List).cast<List<dynamic>>();
      return DcsHookEvent(
        params: rawParams.map((p) => p.cast<int>()).toList(),
        intermediates: (json['intermediates']! as List).cast<int>(),
        finalByte: json['finalByte']! as int,
        ignore: json['ignore']! as bool,
      );
    case 'dcsPut':
      return DcsPutEvent(json['byte']! as int);
    case 'dcsUnhook':
      return const DcsUnhookEvent();
    default:
      throw StateError('unknown event type: ${json['type']}');
  }
}

void main() {
  final fixturesDir = Directory('test/fixtures');
  if (!fixturesDir.existsSync()) {
    // Nothing to do on a clean checkout without captures yet.
    return;
  }

  final bins =
      fixturesDir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.bin'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  if (bins.isEmpty) return;

  group('golden fixtures', () {
    for (final bin in bins) {
      final name = bin.uri.pathSegments.last.replaceAll('.bin', '');
      final jsonPath = 'test/fixtures/$name.events.json';
      final jsonFile = File(jsonPath);

      test('$name roundtrips through VtParser unchanged', () {
        final bytes = bin.readAsBytesSync();
        final golden = (jsonDecode(jsonFile.readAsStringSync()) as List)
            .cast<Map<String, Object?>>()
            .map(_decodeEvent)
            .toList();

        final c = Collector();
        VtParser(sink: c).advance(bytes);
        expect(c.events, golden);
      });
    }
  });
}
