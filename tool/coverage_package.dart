// Runs coverage for the current Melos package and enforces 100% line coverage.

import 'dart:io';

import 'src/helpers.dart';

Future<void> main() async {
  final env = Platform.environment;
  final root = env['MELOS_ROOT_PATH'] ?? repoRoot().path;
  final packagePath = env['MELOS_PACKAGE_PATH'];
  final packageName = env['MELOS_PACKAGE_NAME'];

  if (packagePath == null || packageName == null) {
    stderr.writeln('coverage_package.dart must be run by melos exec.');
    exitCode = 64;
    return;
  }

  final coverageDir = Directory('$packagePath/coverage');
  if (coverageDir.existsSync()) {
    coverageDir.deleteSync(recursive: true);
  }

  stdout.writeln('==> $packageName: dart test --coverage=coverage');
  var code = await runCommand('dart', [
    'test',
    '--coverage=coverage',
  ], workingDirectory: packagePath);
  if (code != 0) {
    exitCode = code;
    return;
  }

  final relativePackagePath = _relativeTo(packagePath, root);
  final lcovPath = '$packagePath/coverage/lcov.info';

  stdout.writeln('==> $packageName: format coverage');
  code = await runCommand('dart', [
    'run',
    'coverage:format_coverage',
    '--lcov',
    '--in=$relativePackagePath/coverage',
    '--out=$relativePackagePath/coverage/lcov.info',
    '--report-on=$relativePackagePath/lib',
    '--check-ignore',
    '--ignore-files=**/*.g.dart',
    '--ignore-files=**/lib/src/bindings/*.dart',
  ], workingDirectory: root);
  if (code != 0) {
    exitCode = code;
    return;
  }

  final uncovered = _uncoveredFiles(File(lcovPath));
  if (uncovered.isNotEmpty) {
    stderr.writeln('$packageName has uncovered lines:');
    for (final file in uncovered) {
      stderr.writeln('  - $file');
    }
    exitCode = 1;
  }
}

List<String> _uncoveredFiles(File lcovFile) {
  final uncovered = <String>[];
  String? sourceFile;
  var foundLines = 0;
  var hitLines = 0;

  void flush() {
    if (sourceFile != null && foundLines > 0 && hitLines < foundLines) {
      uncovered.add(sourceFile!);
    }
    sourceFile = null;
    foundLines = 0;
    hitLines = 0;
  }

  for (final line in lcovFile.readAsLinesSync()) {
    if (line.startsWith('SF:')) {
      flush();
      sourceFile = line.substring(3);
    } else if (line.startsWith('LF:')) {
      foundLines = int.parse(line.substring(3));
    } else if (line.startsWith('LH:')) {
      hitLines = int.parse(line.substring(3));
    } else if (line == 'end_of_record') {
      flush();
    }
  }
  flush();

  return uncovered;
}

String _relativeTo(String path, String root) {
  final normalizedRoot = root.endsWith('/') ? root : '$root/';
  if (path.startsWith(normalizedRoot)) {
    return path.substring(normalizedRoot.length);
  }
  return path;
}
