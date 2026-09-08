import 'dart:convert';

import 'package:bestie_platform_abstractions/bestie_platform_abstractions.dart';
import 'package:file/file.dart';
import 'package:intentions/intentions.dart';
import 'package:process_host/process_host.dart';
import 'package:shell_repository/src/userland/provision_result.dart';

/// Owns the confined agent shell's userland: the coreutils multicall plus one
/// dispatch link per utility, provisioned idempotently via a marker.
@repository
class ShellUserlandRepository {
  ShellUserlandRepository({
    required ExecutableLinkDataSource linkDataSource,
    required FileSystem fileSystem,
    required ProcessRunner processRunner,
  }) : _link = linkDataSource,
       _fs = fileSystem,
       _processRunner = processRunner;

  final ExecutableLinkDataSource _link;
  final FileSystem _fs;
  final ProcessRunner _processRunner;

  static const _markerName = '.coreutils-linked';

  List<String> _utilities = const [];

  /// The utilities on offer, empty until [ensureProvisioned] settles; the
  /// marker carries the names, so a cached launch re-interrogates nothing.
  List<String> get availableUtilities => List.unmodifiable(_utilities);

  /// Ensures the dispatch links exist in [shell]'s `bin/`, skipping the work
  /// when a prior run already provisioned this exact multicall.
  Future<ProvisionResult> ensureProvisioned(ShellUserland shell) async {
    final multicall = _fs.path.join(
      shell.binDir,
      shell.executables.multicallName,
    );
    final multicallFile = _fs.file(multicall);
    if (!multicallFile.existsSync()) {
      return ProvisionFailed('coreutils multicall not found at $multicall');
    }

    final marker = _readMarker(shell);
    if (marker != null && marker.stamp == _stampFor(multicallFile)) {
      _utilities = marker.utilities;
      return const ProvisionUpToDate();
    }

    final result = await _provision(shell, multicall);
    if (result is ProvisionSucceeded) {
      _utilities = result.linkedNames;
      _writeMarker(shell, _stampFor(multicallFile), result.linkedNames);
    }
    return result;
  }

  Future<ProvisionResult> _provision(
    ShellUserland shell,
    String multicall,
  ) async {
    final listed = await _processRunner.runCaptured(
      multicall,
      arguments: const ['--list'],
    );

    switch (listed) {
      case ProcessCaptureNotStarted(:final failure):
        return ProvisionFailed('could not run coreutils: ${failure.message}');

      case ProcessCaptureCompleted(:final exit, :final stdout):
        if (exit is! ProcessExited || exit.code != 0) {
          return ProvisionFailed('`coreutils --list` failed: $exit');
        }
        final linked = <String>[];
        for (final name in _parseUtilNames(utf8.decode(stdout))) {
          final linkPath = _fs.path.join(
            shell.binDir,
            '$name${shell.executables.linkExtension}',
          );
          _removeIfPresent(linkPath);
          final result = _link.link(linkPath: linkPath, targetPath: multicall);
          if (result is ExecutableLinkFailed) {
            return ProvisionFailed('could not link $name: ${result.reason}');
          }
          linked.add(name);
        }
        return ProvisionSucceeded(linked);
    }
  }

  void _removeIfPresent(String path) {
    final type = _fs.typeSync(path, followLinks: false);
    if (type == FileSystemEntityType.notFound) return;
    // A symlink on POSIX, a hardlinked regular file on Windows.
    if (type == FileSystemEntityType.link) {
      _fs.link(path).deleteSync();
    } else {
      _fs.file(path).deleteSync();
    }
  }

  File _markerFile(ShellUserland shell) =>
      _fs.file(_fs.path.join(shell.binDir, _markerName));

  /// Reads the marker, or null when it is absent or predates the utility list —
  /// an unreadable marker simply forces a relink, which is self-healing.
  _Marker? _readMarker(ShellUserland shell) {
    final file = _markerFile(shell);
    if (!file.existsSync()) return null;
    final lines = file.readAsStringSync().split('\n');
    if (lines.length < 2) return null;
    return _Marker(
      stamp: lines.first,
      utilities: lines[1].split(' ').where((name) => name.isNotEmpty).toList(),
    );
  }

  void _writeMarker(ShellUserland shell, String stamp, List<String> utilities) {
    _markerFile(shell).writeAsStringSync('$stamp\n${utilities.join(' ')}');
  }

  /// Identity of the multicall — its size and modification time — so an
  /// upgraded binary invalidates the marker and forces a relink.
  String _stampFor(File multicall) {
    final stat = multicall.statSync();
    return '${stat.size}:${stat.modified.microsecondsSinceEpoch}';
  }

  /// Parses `coreutils --list` output into utility names, dropping the
  /// multicall's own name.
  static List<String> _parseUtilNames(String listOutput) => listOutput
      .split(RegExp(r'[\s,]+'))
      .map((name) => name.trim())
      .where((name) => name.isNotEmpty && name != 'coreutils')
      .toList();
}

/// The parsed contents of the provisioning marker.
class _Marker {
  const _Marker({required this.stamp, required this.utilities});

  /// Identity of the multicall this marker was written for.
  final String stamp;

  /// The utilities linked when it was written.
  final List<String> utilities;
}
