import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:file/file.dart';
import 'package:inference_server/src/inference_lock.dart';
import 'package:inference_server/src/inference_server.dart';
import 'package:inference_server/src/lifetime/server_lifetime.dart';
import 'package:inference_server/src/lifetime/server_stop_reason.dart';
import 'package:inference_server/src/model_engine.dart';
import 'package:inference_server/src/model_host.dart';
import 'package:inference_server/src/model_index_reader.dart';
import 'package:inference_server/src/owner_session.dart';
import 'package:inference_server/src/server_log.dart';
import 'package:local_inference_protocol/local_inference_protocol.dart';
import 'package:path/path.dart' as p;

/// Runs one server for a bestie directory from lock to shutdown.
final class ServerLaunch {
  ServerLaunch({
    required this.bestieDir,
    required ModelEngineStarter engineStarter,
    required ServerLog log,
    required FileSystem fileSystem,
    required this.serverVersion,
    required this.pid,
    required Stream<void> shutdownRequests,
    Future<HttpServer> Function()? bind,
    Random? random,
    DateTime Function()? now,
    this.startupGrace = ServerLifetime.defaultStartupGrace,
    this.lockWait = defaultLockWait,
  }) : _engineStarter = engineStarter,
       _bind = bind ?? _bindLoopback,
       _log = log,
       _fileSystem = fileSystem,
       _shutdownRequests = shutdownRequests,
       _random = random ?? Random.secure(),
       _now = now ?? DateTime.now;

  /// How long a server that is still letting go of the lock is waited for.
  static const defaultLockWait = Duration(seconds: 10);

  static const _lockRetry = Duration(milliseconds: 100);

  final String bestieDir;

  /// How long to wait for a first connection before exiting.
  final Duration startupGrace;

  /// How long to keep trying for a lock another server holds; a server
  /// shutting down holds it until it has unloaded.
  final Duration lockWait;

  final String serverVersion;

  final int pid;

  final ModelEngineStarter _engineStarter;
  final ServerLog _log;
  final FileSystem _fileSystem;
  final Stream<void> _shutdownRequests;
  final Future<HttpServer> Function() _bind;
  final Random _random;
  final DateTime Function() _now;

  static Future<HttpServer> _bindLoopback() =>
      HttpServer.bind(InternetAddress.loopbackIPv4, 0);

  String get lockPath => p.join(bestieDir, 'run', InferenceLockFile.fileName);

  String get indexPath => p.join(bestieDir, 'models', ModelIndex.fileName);

  /// Takes the lock, starts the engine, and serves until the last
  /// connection closes or it is asked to stop. Nothing native starts until
  /// the lock is held, and the engine is closed however serving ends.
  Future<ServerExit> run() async {
    final exit = switch (await _acquireLock()) {
      InferenceLockHeld(:final holder) => _alreadyRunning(holder),
      InferenceLockFailed(:final message) => _lockFailed(message),
      InferenceLockAcquired(:final lock) => await _runLocked(lock),
    };
    _log.info('Stopped with exit code ${exit.exitCode}.');
    return exit;
  }

  /// The lock, retried for [lockWait] while another server holds it.
  Future<InferenceLockAcquisition> _acquireLock() async {
    final deadline = _now().add(lockWait);
    var acquisition = InferenceLock.acquire(lockPath);
    if (acquisition is InferenceLockHeld) {
      _log.info('Waiting for the server holding $lockPath to let go.');
    }
    while (acquisition is InferenceLockHeld && _now().isBefore(deadline)) {
      await Future<void>.delayed(_lockRetry);
      acquisition = InferenceLock.acquire(lockPath);
    }
    return acquisition;
  }

  ServerExit _alreadyRunning(InferenceLockFile? holder) {
    _log.error('Another server holds $lockPath (pid ${holder?.pid}).');
    return ServerAlreadyRunning(holder: holder);
  }

  ServerExit _lockFailed(String message) {
    _log.error('Could not open the lock: $message');
    return ServerLockFailed(message: message);
  }

  Future<ServerExit> _runLocked(InferenceLock lock) async {
    try {
      switch (await _engineStarter.start(_log)) {
        case ModelEngineLibrariesMissing(:final message):
          _log.error(message);
          return ServerLibrariesMissing(message: message);
        case ModelEngineFailedToStart(:final message):
          _log.error('Could not start the engine: $message');
          return ServerEngineFailed(message: message);
        case ModelEngineStarted(:final engine):
          final exit = await _serve(lock, engine);
          await engine.close();
          return exit;
      }
    } finally {
      lock.release();
    }
  }

  Future<ServerExit> _serve(InferenceLock lock, ModelEngine engine) async {
    final HttpServer http;
    try {
      http = await _bind();
    } on SocketException catch (error) {
      _log.error('Could not listen: ${error.message}');
      return ServerBindFailed(message: error.message);
    }
    lock.publish(
      InferenceLockFile(
        pid: pid,
        port: http.port,
        protocolVersion: bestieProtocolVersion,
      ),
    );
    _log.info('Listening on 127.0.0.1:${http.port} (pid $pid).');

    final lifetime = ServerLifetime(startupGrace: startupGrace)..start();
    final index = ModelIndexReader(fileSystem: _fileSystem, path: indexPath);
    final host = ModelHost(engine: engine, index: index);
    final server = InferenceServer(
      host: host,
      index: index,
      owners: OwnerSessions(mintToken: _mintId),
      lifetime: lifetime,
      log: _log,
      serverVersion: serverVersion,
      pid: pid,
      now: _now,
      mintCompletionId: _mintId,
    );
    final shutdown = _shutdownRequests.listen(
      (_) => lifetime.requestShutdown(),
    );
    unawaited(server.serve(http));

    final reason = await lifetime.ended;
    _log.info('Shutting down (${reason.name}).');
    await shutdown.cancel();
    await http.close();
    await server.close();
    lifetime.dispose();
    return ServerStopped(reason: reason);
  }

  String _mintId() => [
    for (var index = 0; index < 16; index++)
      _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ].join();
}

/// How a server run ended, with the process exit code it maps to.
sealed class ServerExit {
  const ServerExit();

  int get exitCode;
}

final class ServerStopped extends ServerExit {
  const ServerStopped({required this.reason});

  final ServerStopReason reason;

  @override
  int get exitCode => 0;
}

/// Another server already runs for this bestie directory.
final class ServerAlreadyRunning extends ServerExit {
  const ServerAlreadyRunning({required this.holder});

  final InferenceLockFile? holder;

  @override
  int get exitCode => 75;
}

final class ServerLockFailed extends ServerExit {
  const ServerLockFailed({required this.message});

  final String message;

  @override
  int get exitCode => 73;
}

/// The native libraries the engine needs are missing.
final class ServerLibrariesMissing extends ServerExit {
  const ServerLibrariesMissing({required this.message});

  final String message;

  @override
  int get exitCode => 72;
}

final class ServerEngineFailed extends ServerExit {
  const ServerEngineFailed({required this.message});

  final String message;

  @override
  int get exitCode => 70;
}

final class ServerBindFailed extends ServerExit {
  const ServerBindFailed({required this.message});

  final String message;

  @override
  int get exitCode => 69;
}
