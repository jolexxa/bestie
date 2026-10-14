import 'dart:convert';
import 'dart:io';

// We don't want to give up concurrency during testing since we have so
// much code, so we do some dirty tricks to retry if we hit some Dart quirks.

/// What the Dart 3.13 test runner prints when it reads the workspace
/// `.dart_tool/native_assets.yaml` while another package's `dart test` is
/// rewriting it (https://github.com/dart-lang/sdk/issues/60489).
const _rewriteMarker = 'File not formatted as yaml';

const _attempts = 3;

/// Runs `dart test` with [arguments] in [workingDirectory], retrying when the
/// run only failed because the workspace native assets file was mid-rewrite.
Future<int> runDartTest(
  List<String> arguments, {
  required String workingDirectory,
}) async {
  for (var attempt = 1; ; attempt++) {
    final run = await _runOnce(arguments, workingDirectory);
    if (run.exitCode == 0 || !run.hitRewrite || attempt == _attempts) {
      return run.exitCode;
    }
    stderr.writeln(
      'native_assets.yaml was being rewritten by another package; '
      'retrying dart test ($attempt/$_attempts)',
    );
  }
}

Future<_TestRun> _runOnce(
  List<String> arguments,
  String workingDirectory,
) async {
  final process = await Process.start('dart', [
    'test',
    ...arguments,
  ], workingDirectory: workingDirectory);
  final hits = await Future.wait([
    _forward(process.stdout, stdout),
    _forward(process.stderr, stderr),
  ]);
  return _TestRun(await process.exitCode, hitRewrite: hits.contains(true));
}

Future<bool> _forward(Stream<List<int>> from, IOSink to) async {
  var hit = false;
  final lines = from
      .transform(const Utf8Decoder(allowMalformed: true))
      .transform(const LineSplitter());
  await for (final line in lines) {
    to.writeln(line);
    hit = hit || line.contains(_rewriteMarker);
  }
  return hit;
}

class _TestRun {
  const _TestRun(this.exitCode, {required this.hitRewrite});

  final int exitCode;

  /// Whether the output mentioned the native assets file being rewritten.
  final bool hitRewrite;
}
