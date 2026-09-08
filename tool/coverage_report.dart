// Generates non-failing coverage reports for workspace packages with tests.

import 'dart:async';
import 'dart:io';

import 'package:chalkdart/chalk.dart';

import 'src/helpers.dart';

const _defaultJobs = 8;

Future<void> main(List<String> args) async {
  final options = _Options.parse(args);
  if (options.showHelp) {
    _printHelp();
    return;
  }

  final root = repoRoot().path;
  final colors = _Colors(enabled: options.color);
  final packages = await _coveragePackages(root);

  if (packages.isEmpty) {
    stderr.writeln(
      'No non-e2e workspace packages with test directories found.',
    );
    return;
  }

  stdout.writeln(
    colors.header(
      'Coverage report: ${packages.length} packages, ${options.jobs} jobs',
    ),
  );
  stdout.writeln('');

  final results = await _runPackages(
    root,
    packages,
    jobs: options.jobs,
    verbose: options.verbose,
    colors: colors,
  );

  stdout.writeln('');
  _printSummary(results, colors);
}

Future<List<_CoverageResult>> _runPackages(
  String root,
  List<_PackageRef> packages, {
  required int jobs,
  required bool verbose,
  required _Colors colors,
}) async {
  final results = List<_CoverageResult?>.filled(packages.length, null);
  var nextIndex = 0;

  Future<void> worker() async {
    while (true) {
      final index = nextIndex;
      nextIndex += 1;
      if (index >= packages.length) return;

      final package = packages[index];
      final ordinal = '[${index + 1}/${packages.length}]';
      stdout.writeln('${colors.muted(ordinal)} ${colors.active(package.name)}');
      final result = await _runPackage(root, package, verbose: verbose);
      results[index] = result;
      stdout.writeln(_progressLine(result, colors));
    }
  }

  await Future.wait([
    for (var i = 0; i < jobs && i < packages.length; i += 1) worker(),
  ]);

  return results.cast<_CoverageResult>();
}

String _progressLine(_CoverageResult result, _Colors colors) {
  final prefix = colors.muted('    ->');
  final duration = colors.muted(_formatDuration(result.elapsed));
  final coverage = result.coverage;
  if (coverage == null) {
    return '$prefix ${colors.failure('failed')} '
        '${colors.active(result.package.name)} '
        '${colors.muted(result.failureStage ?? 'unknown')} $duration';
  }
  final status = coverage.uncoveredFiles.isEmpty
      ? colors.success('complete')
      : colors.warning('partial');
  return '$prefix $status ${colors.percent(coverage.percent)} '
      '${colors.active(result.package.name)} '
      '${coverage.hitLines}/${coverage.foundLines} lines $duration';
}

Future<List<_PackageRef>> _coveragePackages(String root) async {
  final result = await Process.run('dart', [
    'run',
    'melos',
    'list',
    '--dir-exists=test',
    '--ignore=cow_e2e',
    '--parsable',
  ], workingDirectory: root);

  if (result.exitCode != 0) {
    stderr
      ..writeln('Failed to list Melos packages with tests.')
      ..write(result.stderr);
    return const [];
  }

  final paths = (result.stdout as String)
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty)
      .toList();

  return [
    for (final path in paths)
      _PackageRef(path: path, name: path.split('/').last),
  ];
}

Future<_CoverageResult> _runPackage(
  String root,
  _PackageRef package, {
  required bool verbose,
}) async {
  final stopwatch = Stopwatch()..start();
  final coverageDir = Directory('${package.path}/coverage');
  if (coverageDir.existsSync()) {
    coverageDir.deleteSync(recursive: true);
  }

  final test = await _runQuiet(
    'dart',
    ['test', '--coverage=coverage'],
    workingDirectory: package.path,
    verbose: verbose,
  );
  if (test.exitCode != 0) {
    return _CoverageResult.failed(
      package: package,
      stage: 'test',
      output: test.output,
      elapsed: stopwatch.elapsed,
    );
  }

  final relativePath = _relativeTo(package.path, root);
  final format = await _runQuiet(
    'dart',
    [
      'run',
      'coverage:format_coverage',
      '--lcov',
      '--in=$relativePath/coverage',
      '--out=$relativePath/coverage/lcov.info',
      '--report-on=$relativePath/lib',
      '--check-ignore',
      '--ignore-files=**/*.g.dart',
    ],
    workingDirectory: root,
    verbose: verbose,
  );
  if (format.exitCode != 0) {
    return _CoverageResult.failed(
      package: package,
      stage: 'format',
      output: format.output,
      elapsed: stopwatch.elapsed,
    );
  }

  final lcovFile = File('${package.path}/coverage/lcov.info');
  return _CoverageResult.covered(
    package: package,
    coverage: _readCoverage(lcovFile),
    elapsed: stopwatch.elapsed,
  );
}

Future<_CommandResult> _runQuiet(
  String executable,
  List<String> arguments, {
  required String workingDirectory,
  required bool verbose,
}) async {
  final result = await Process.run(
    executable,
    arguments,
    workingDirectory: workingDirectory,
  );
  final output = [
    if ((result.stdout as String).isNotEmpty) result.stdout as String,
    if ((result.stderr as String).isNotEmpty) result.stderr as String,
  ].join('\n');

  if (verbose && output.trim().isNotEmpty) {
    stdout.write(output);
    if (!output.endsWith('\n')) stdout.writeln();
  }

  return _CommandResult(exitCode: result.exitCode, output: output);
}

_CoverageData _readCoverage(File file) {
  var sourceFile = '';
  var foundLines = 0;
  var hitLines = 0;
  final files = <_FileCoverage>[];

  void flush() {
    if (sourceFile.isNotEmpty && foundLines > 0) {
      files.add(
        _FileCoverage(
          path: sourceFile,
          foundLines: foundLines,
          hitLines: hitLines,
        ),
      );
    }
    sourceFile = '';
    foundLines = 0;
    hitLines = 0;
  }

  for (final line in file.readAsLinesSync()) {
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

  return _CoverageData(files);
}

void _printSummary(List<_CoverageResult> results, _Colors colors) {
  const nameW = 30;
  const pctW = 10;
  const linesW = 15;
  const missingW = 11;
  const timeW = 9;
  const statusW = 12;
  const width = nameW + pctW + linesW + missingW + timeW + statusW;

  stdout.writeln(colors.header('Summary'));
  stdout.writeln(
    colors.muted(
      '${'Package'.padRight(nameW)}'
      '${'Coverage'.padLeft(pctW)}'
      '${'Lines'.padLeft(linesW)}'
      '${'Files'.padLeft(missingW)}'
      '${'Time'.padLeft(timeW)}'
      '${'Status'.padLeft(statusW)}',
    ),
  );
  stdout.writeln(colors.muted('-' * width));

  for (final result in results) {
    stdout.writeln(_summaryRow(result, colors));
  }

  final covered = results.where((result) => result.coverage != null).toList();
  if (covered.isNotEmpty) {
    stdout.writeln(colors.muted('-' * width));
    stdout.writeln(_totalRow(covered, colors));
  }

  final failures = results.where((result) => result.failureStage != null);
  if (failures.isNotEmpty) {
    stdout.writeln('');
    stdout.writeln(colors.failure('Failures'));
    for (final failure in failures) {
      stdout.writeln(
        '  ${colors.failure(failure.package.name)} '
        '${colors.muted(failure.failureStage ?? 'unknown')}',
      );
      final output = failure.failureOutput.trim();
      if (output.isNotEmpty) {
        for (final line in output.split('\n').take(8)) {
          stdout.writeln('    ${colors.muted(line)}');
        }
      }
    }
  }
}

String _summaryRow(_CoverageResult result, _Colors colors) {
  const nameW = 30;
  const pctW = 10;
  const linesW = 15;
  const missingW = 11;
  const timeW = 9;
  const statusW = 12;

  final coverage = result.coverage;
  final percent = coverage == null ? '-' : coverage.percentLabel;
  final lines = coverage == null
      ? '-'
      : '${coverage.hitLines}/${coverage.foundLines}';
  final missing = coverage == null
      ? '-'
      : coverage.uncoveredFiles.length.toString();
  final status = result.status;

  return result.package.name.padRight(nameW) +
      colors.percentLabel(percent.padLeft(pctW), coverage?.percent) +
      lines.padLeft(linesW) +
      missing.padLeft(missingW) +
      _formatDuration(result.elapsed).padLeft(timeW) +
      colors.status(status.padLeft(statusW), status);
}

String _totalRow(List<_CoverageResult> results, _Colors colors) {
  const nameW = 30;
  const pctW = 10;
  const linesW = 15;
  const missingW = 11;
  const timeW = 9;
  const statusW = 12;

  final totalHit = results.fold<int>(
    0,
    (sum, result) => sum + result.coverage!.hitLines,
  );
  final totalFound = results.fold<int>(
    0,
    (sum, result) => sum + result.coverage!.foundLines,
  );
  final totalMissing = results.fold<int>(
    0,
    (sum, result) => sum + result.coverage!.uncoveredFiles.length,
  );
  final elapsed = results.fold<Duration>(
    Duration.zero,
    (sum, result) => sum + result.elapsed,
  );
  final percent = totalFound == 0 ? 100.0 : totalHit * 100 / totalFound;
  final status = totalMissing == 0 ? 'complete' : 'partial';

  return colors.bold('TOTAL'.padRight(nameW)) +
      colors.percentLabel(
        '${percent.toStringAsFixed(1)}%'.padLeft(pctW),
        percent,
      ) +
      '$totalHit/$totalFound'.padLeft(linesW) +
      totalMissing.toString().padLeft(missingW) +
      _formatDuration(elapsed).padLeft(timeW) +
      colors.status(status.padLeft(statusW), status);
}

void _printHelp() {
  stdout.writeln('''
Generate coverage reports for non-e2e workspace packages with tests.

Usage:
  dart --packages=.dart_tool/package_config.json tool/coverage_report.dart [options]

Options:
  --jobs=N       Number of packages to run concurrently. Defaults to 8.
  --jobs N       Same as --jobs=N.
  --job=N        Same as --jobs=N.
  --job N        Same as --jobs=N.
  --verbose      Print test and coverage command output.
  --no-color     Disable ANSI color output.
  --help         Show this help.
''');
}

String _relativeTo(String path, String root) {
  final normalizedRoot = root.endsWith('/') ? root : '$root/';
  if (path.startsWith(normalizedRoot)) {
    return path.substring(normalizedRoot.length);
  }
  return path;
}

String _formatDuration(Duration duration) {
  if (duration.inMinutes > 0) {
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '${duration.inMinutes}m${seconds}s';
  }
  if (duration.inSeconds > 0) return '${duration.inSeconds}s';
  return '${duration.inMilliseconds}ms';
}

final class _Options {
  const _Options({
    required this.jobs,
    required this.verbose,
    required this.color,
    required this.showHelp,
  });

  factory _Options.parse(List<String> args) {
    var jobs = _defaultJobs;
    var verbose = false;
    var color = stdout.supportsAnsiEscapes;
    var showHelp = false;

    for (var i = 0; i < args.length; i += 1) {
      final arg = args[i];
      if (arg == '--help' || arg == '-h') {
        showHelp = true;
      } else if (arg == '--verbose') {
        verbose = true;
      } else if (arg == '--no-color') {
        color = false;
      } else if (arg.startsWith('--jobs=')) {
        jobs = _parseJobs(arg.substring('--jobs='.length));
      } else if (arg.startsWith('--job=')) {
        jobs = _parseJobs(arg.substring('--job='.length));
      } else if ((arg == '--jobs' || arg == '--job') && i + 1 < args.length) {
        i += 1;
        jobs = _parseJobs(args[i]);
      } else {
        stderr.writeln('Ignoring unknown argument: $arg');
      }
    }

    return _Options(
      jobs: jobs.clamp(1, 64),
      verbose: verbose,
      color: color,
      showHelp: showHelp,
    );
  }

  static int _parseJobs(String value) {
    final parsed = int.tryParse(value);
    if (parsed == null || parsed < 1) return _defaultJobs;
    return parsed;
  }

  final int jobs;
  final bool verbose;
  final bool color;
  final bool showHelp;
}

final class _Colors {
  _Colors({required bool enabled}) : _chalk = Chalk(level: enabled ? 3 : 0);

  final Chalk _chalk;

  String header(Object value) => _chalk.cyan.bold(value);
  String active(Object value) => _chalk.blue(value);
  String success(Object value) => _chalk.green(value);
  String warning(Object value) => _chalk.yellow(value);
  String failure(Object value) => _chalk.red(value);
  String muted(Object value) => _chalk.gray(value);
  String bold(Object value) => _chalk.bold(value);

  String percent(double value) =>
      percentLabel('${value.toStringAsFixed(1)}%', value);

  String percentLabel(String label, double? value) {
    if (value == null) return muted(label);
    if (value >= 100) return success(label);
    if (value >= 90) return warning(label);
    return failure(label);
  }

  String status(String label, String status) {
    return switch (status) {
      'complete' => success(label),
      'partial' => warning(label),
      'failed' => failure(label),
      _ => muted(label),
    };
  }
}

final class _PackageRef {
  const _PackageRef({required this.path, required this.name});

  final String path;
  final String name;
}

final class _CommandResult {
  const _CommandResult({required this.exitCode, required this.output});

  final int exitCode;
  final String output;
}

final class _CoverageResult {
  const _CoverageResult._({
    required this.package,
    required this.elapsed,
    this.coverage,
    this.failureStage,
    this.failureOutput = '',
  });

  factory _CoverageResult.covered({
    required _PackageRef package,
    required _CoverageData coverage,
    required Duration elapsed,
  }) =>
      _CoverageResult._(package: package, coverage: coverage, elapsed: elapsed);

  factory _CoverageResult.failed({
    required _PackageRef package,
    required String stage,
    required String output,
    required Duration elapsed,
  }) => _CoverageResult._(
    package: package,
    failureStage: stage,
    failureOutput: output,
    elapsed: elapsed,
  );

  final _PackageRef package;
  final _CoverageData? coverage;
  final String? failureStage;
  final String failureOutput;
  final Duration elapsed;

  String get status {
    if (failureStage != null) return 'failed';
    final data = coverage;
    if (data == null) return 'unknown';
    return data.uncoveredFiles.isEmpty ? 'complete' : 'partial';
  }
}

final class _CoverageData {
  _CoverageData(this.files);

  final List<_FileCoverage> files;

  int get foundLines => files.fold(0, (sum, file) => sum + file.foundLines);
  int get hitLines => files.fold(0, (sum, file) => sum + file.hitLines);
  double get percent => foundLines == 0 ? 100 : hitLines * 100 / foundLines;
  List<_FileCoverage> get uncoveredFiles =>
      files.where((file) => file.hitLines < file.foundLines).toList();

  String get percentLabel =>
      foundLines == 0 ? '-' : '${percent.toStringAsFixed(1)}%';
}

final class _FileCoverage {
  const _FileCoverage({
    required this.path,
    required this.foundLines,
    required this.hitLines,
  });

  final String path;
  final int foundLines;
  final int hitLines;
}
