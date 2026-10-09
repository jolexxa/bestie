import 'dart:async';
import 'dart:convert';
import 'dart:io' show HttpStatus;

import 'package:http/http.dart' as http;
import 'package:intentions/intentions.dart';
import 'package:local_inference_client/src/local_inference_client.dart';
import 'package:local_inference_client/src/server_api.dart';
import 'package:local_inference_protocol/local_inference_protocol.dart';

/// The owner session's event stream, held open on a client of its own so
/// closing it hangs up at once and the server frees every lease.
@PartOf(LocalInferenceClient)
final class OwnerSession {
  OwnerSession._({
    required http.Client client,
    required this.ownerToken,
    required StreamIterator<SessionEvent> events,
  }) : _client = client,
       _events = events;

  /// Asks the server on [port] for the owner session on behalf of [pid].
  static Future<OwnerSessionOpening> open({
    required http.Client client,
    required int port,
    required int pid,
  }) async {
    final request = http.Request(
      'GET',
      ServerApi.urlFor(port, bestieSessionPath),
    )..headers[bestieOwnerPidHeader] = '$pid';
    final http.StreamedResponse response;
    try {
      response = await client.send(request);
    } on Object catch (error) {
      client.close();
      return OwnerSessionServerGone('$error');
    }
    try {
      if (response.statusCode == HttpStatus.serviceUnavailable) {
        client.close();
        return OwnerSessionServerGone(
          _reasonIn(
            await response.stream.bytesToString(),
            status: response.statusCode,
          ),
        );
      }
      if (response.statusCode == ServerBusy.statusCode) {
        final busy = ServerErrorMapper.fromJson(
          await response.stream.bytesToString(),
        );
        client.close();
        return switch (busy) {
          ServerBusy(:final ownerPid) => OwnerSessionRefused(
            ownerPid: ownerPid,
          ),
        };
      }
      if (response.statusCode != 200) {
        client.close();
        return OwnerSessionFailed(
          'The local model server answered the session with HTTP '
          '${response.statusCode}.',
        );
      }
      final events = StreamIterator(_eventsIn(response.stream));
      if (await events.moveNext()) {
        if (events.current case SessionOpened(:final ownerToken)) {
          return OwnerSessionOpened(
            OwnerSession._(
              client: client,
              ownerToken: ownerToken,
              events: events,
            ),
          );
        }
      }
      await events.cancel();
      client.close();
      return const OwnerSessionFailed(
        'The local model server did not open the session.',
      );
    } on Object catch (error) {
      client.close();
      return OwnerSessionFailed('$error');
    }
  }

  final http.Client _client;
  final StreamIterator<SessionEvent> _events;

  final String ownerToken;

  /// Every event after the opening one, until the session ends.
  Stream<SessionEvent> get events async* {
    try {
      while (await _events.moveNext()) {
        yield _events.current;
      }
    } on Object {
      return;
    }
  }

  /// Hangs up; the server releases this owner's leases.
  Future<void> close() async {
    _client.close();
    await _events.cancel();
  }

  static String _reasonIn(String body, {required int status}) {
    try {
      if (jsonDecode(body) case {'error': {'message': final String message}}) {
        return message;
      }
    } on FormatException {
      // Not JSON; the status says enough.
    }
    return 'The local model server answered the session with HTTP $status.';
  }

  /// Session events from the server-sent stream; events this client does
  /// not know are skipped.
  static Stream<SessionEvent> _eventsIn(Stream<List<int>> bytes) => bytes
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .where((line) => line.startsWith('data:'))
      .expand((line) => [?_decode(line.substring('data:'.length).trim())]);

  static SessionEvent? _decode(String data) {
    try {
      return SessionEventMapper.fromJson(data);
    } on Object {
      return null;
    }
  }
}

/// How asking for the owner session went.
@PartOf(LocalInferenceClient)
sealed class OwnerSessionOpening {
  const OwnerSessionOpening();
}

@PartOf(LocalInferenceClient)
final class OwnerSessionOpened extends OwnerSessionOpening {
  const OwnerSessionOpened(this.session);

  final OwnerSession session;
}

/// Another bestie holds the session.
@PartOf(LocalInferenceClient)
final class OwnerSessionRefused extends OwnerSessionOpening {
  const OwnerSessionRefused({required this.ownerPid});

  final int ownerPid;
}

/// The server was gone or shutting down by the time the session was asked
/// for, so another one has to be found or started.
@PartOf(LocalInferenceClient)
final class OwnerSessionServerGone extends OwnerSessionOpening {
  const OwnerSessionServerGone(this.reason);

  final String reason;
}

@PartOf(LocalInferenceClient)
final class OwnerSessionFailed extends OwnerSessionOpening {
  const OwnerSessionFailed(this.reason);

  final String reason;
}
