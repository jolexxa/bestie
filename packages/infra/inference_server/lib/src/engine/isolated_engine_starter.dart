import 'dart:async';
import 'dart:isolate';

import 'package:inference_server/src/engine/engine_host.dart';
import 'package:inference_server/src/engine/engine_messages.dart';
import 'package:inference_server/src/engine/remote_model_engine.dart';
import 'package:inference_server/src/model_engine.dart';
import 'package:inference_server/src/server_log.dart';

/// Starts the engine [inner] builds in an isolate of its own, so models load
/// and completions step without ever blocking the isolate that serves HTTP.
/// [inner] is sent to the new isolate, so it must hold only plain data.
final class IsolatedEngineStarter implements ModelEngineStarter {
  const IsolatedEngineStarter(this.inner);

  final ModelEngineStarter inner;

  @override
  Future<ModelEngineStart> start(ServerLog log) async {
    final replies = ReceivePort('engine replies');
    final exits = ReceivePort('engine exits');
    final errors = ReceivePort('engine errors');
    void closePorts() {
      replies.close();
      exits.close();
      errors.close();
    }

    final answered = Completer<EngineStartAnswered>();
    final forwarded = StreamController<EngineReply>(sync: true);
    replies.cast<EngineMessage>().listen(
      (message) => switch (message) {
        final EngineStartAnswered answer => answered.complete(answer),
        EngineLogged(:final message, isError: true) => log.error(message),
        EngineLogged(:final message) => log.info(message),
        final EngineReply reply => forwarded.add(reply),
      },
    );
    errors.listen((error) => log.error('The engine broke: $error'));

    final Isolate isolate;
    try {
      isolate = await Isolate.spawn(
        _runEngine,
        _EngineBoot(starter: inner, replies: replies.sendPort),
        onExit: exits.sendPort,
        onError: errors.sendPort,
        debugName: 'model engine',
      );
    } on Object catch (error) {
      closePorts();
      return ModelEngineFailedToStart(message: '$error');
    }

    RemoteModelEngine? engine;
    exits.listen((_) {
      if (!answered.isCompleted) {
        answered.complete(
          EngineStartAnswered(
            commands: replies.sendPort,
            unavailable: const ModelEngineFailedToStart(
              message: 'The engine stopped while starting.',
            ),
          ),
        );
      }
      engine?.lose('The engine stopped.');
      closePorts();
    });

    final answer = await answered.future;
    final unavailable = answer.unavailable;
    if (unavailable != null) {
      isolate.kill(priority: Isolate.immediate);
      return unavailable;
    }
    engine = RemoteModelEngine(
      send: answer.commands.send,
      replies: forwarded.stream,
      terminate: () async => isolate.kill(priority: Isolate.immediate),
    );
    return ModelEngineStarted(engine);
  }
}

final class _EngineBoot {
  const _EngineBoot({required this.starter, required this.replies});

  final ModelEngineStarter starter;

  final SendPort replies;
}

Future<void> _runEngine(_EngineBoot boot) async {
  final commands = ReceivePort('engine commands');
  final send = boot.replies.send;
  final started = await boot.starter.start(_ForwardedLog(send));
  switch (started) {
    case ModelEngineStarted(:final engine):
      final host = EngineHost(engine: engine, send: send);
      commands.cast<EngineCommand>().listen(host.handle);
      send(EngineStartAnswered(commands: commands.sendPort));
    case final ModelEngineUnavailable unavailable:
      commands.close();
      send(
        EngineStartAnswered(
          commands: commands.sendPort,
          unavailable: unavailable,
        ),
      );
  }
}

final class _ForwardedLog implements ServerLog {
  const _ForwardedLog(this._send);

  final void Function(EngineMessage message) _send;

  @override
  void info(String message) =>
      _send(EngineLogged(message: message, isError: false));

  @override
  void error(String message) =>
      _send(EngineLogged(message: message, isError: true));
}
