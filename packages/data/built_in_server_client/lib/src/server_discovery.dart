import 'dart:async';
import 'dart:math' as math;

import 'package:built_in_server_client/src/built_in_server_client.dart';
import 'package:built_in_server_client/src/models/built_in_server_launch.dart';
import 'package:built_in_server_client/src/models/server_results.dart';
import 'package:built_in_server_client/src/server_api.dart';
import 'package:built_in_server_client/src/server_spawner.dart';
import 'package:clock/clock.dart';
import 'package:file/file.dart';
import 'package:intentions/intentions.dart';
import 'package:local_server_protocol/local_server_protocol.dart';
import 'package:process_host/process_host.dart';

/// Finds the server the lock file names, starting one when none answers.
@PartOf(BuiltInServerClient)
final class ServerDiscovery {
  ServerDiscovery({
    required ServerApi api,
    required FileSystem fileSystem,
    required String lockFile,
    required BuiltInServerLaunch launch,
    required ServerSpawner spawner,
    required Clock clock,
    required Duration startTimeout,
  }) : _api = api,
       _fileSystem = fileSystem,
       _lockFile = lockFile,
       _launch = launch,
       _spawner = spawner,
       _clock = clock,
       _startTimeout = startTimeout;

  static const _firstPoll = Duration(milliseconds: 100);
  static const _slowestPoll = Duration(seconds: 1);

  /// How many times a server the lock file names is asked before it counts
  /// as gone; a busy server can stall one handshake.
  static const _handshakeAttempts = 2;

  final ServerApi _api;
  final FileSystem _fileSystem;
  final String _lockFile;
  final BuiltInServerLaunch _launch;
  final ServerSpawner _spawner;
  final Clock _clock;
  final Duration _startTimeout;
  Future<ServerDiscoveryResult>? _finding;
  ServerSpawned? _spawned;

  /// The running server, or a new one. A server shutting down answers no
  /// handshake, so it counts as gone; the one started in its place waits
  /// for it to let go of the lock. Concurrent callers share one search.
  Future<ServerDiscoveryResult> find() =>
      _finding ??= _find().whenComplete(() => _finding = null);

  Future<ServerDiscoveryResult> _find() async {
    final running = await _probe(attempts: _handshakeAttempts);
    if (running != null) return running;
    final command = _launch.command;
    _prepareLog();
    switch (await _spawner.spawn(command.executable, _launch.arguments)) {
      case ServerSpawnRefused(:final reason):
        return ServerNotStarted(reason);
      case final ServerSpawned spawned:
        _spawned = spawned;
        return _awaitStart();
    }
  }

  Future<ServerDiscoveryResult> _awaitStart() async {
    final deadline = _clock.now().add(_startTimeout);
    var wait = _firstPoll;
    while (_clock.now().isBefore(deadline)) {
      await Future<void>.delayed(wait);
      final started = await _probe(attempts: 1);
      if (started != null) return started;
      wait = Duration(
        microseconds: math.min(
          wait.inMicroseconds * 2,
          _slowestPoll.inMicroseconds,
        ),
      );
    }
    return ServerNotStarted(
      'The local model server did not start within '
      '${_startTimeout.inSeconds} seconds; see ${_launch.logFile}.',
    );
  }

  /// The server the lock file names, or null when none answers. A server
  /// this discovery started is handed over with its exit, so its end can
  /// be told from a server that was merely found.
  Future<ServerDiscoveryResult?> _probe({required int attempts}) async {
    final port = _lockedPort();
    if (port == null) return null;
    for (var attempt = 0; attempt < attempts; attempt++) {
      final health = await _api.health(port);
      if (health == null) continue;
      if (health.protocolVersion != bestieProtocolVersion) {
        return ServerSpeaksOtherProtocol(health);
      }
      final spawned = _spawned;
      return ServerFound(
        port: port,
        health: health,
        exit: spawned?.pid == health.pid ? spawned?.exit : null,
      );
    }
    return null;
  }

  /// The server appends to its log but cannot make the folder it lives in.
  void _prepareLog() {
    try {
      _fileSystem.file(_launch.logFile).parent.createSync(recursive: true);
    } on FileSystemException {
      return;
    }
  }

  int? _lockedPort() {
    try {
      final text = _fileSystem.file(_lockFile).readAsStringSync();
      return ServerLockFileMapper.fromJson(text).port;
    } on Object {
      return null;
    }
  }
}

/// What looking for the server found.
@model
sealed class ServerDiscoveryResult {
  const ServerDiscoveryResult();
}

@model
final class ServerFound extends ServerDiscoveryResult {
  const ServerFound({required this.port, required this.health, this.exit});

  final int port;

  final HealthResponse health;

  /// How the server process ends, when this bestie started it.
  final Future<ProcessExit>? exit;
}

/// A server runs, but it speaks another protocol version.
@model
final class ServerSpeaksOtherProtocol extends ServerDiscoveryResult {
  const ServerSpeaksOtherProtocol(this.health);

  final HealthResponse health;
}

@model
final class ServerNotStarted extends ServerDiscoveryResult {
  const ServerNotStarted(this.reason);

  final String reason;
}
