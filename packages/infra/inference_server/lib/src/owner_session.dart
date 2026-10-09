import 'dart:async';

import 'package:local_inference_protocol/local_inference_protocol.dart';

/// The one client allowed to lease agents and load models, and the stream
/// of session events it is sent.
final class Owner {
  Owner({required this.token, required this.pid});

  final String token;

  final int pid;

  final _events = StreamController<SessionEvent>();

  Stream<SessionEvent> get events => _events.stream;

  void send(SessionEvent event) {
    if (!_events.isClosed) _events.add(event);
  }

  void _end() => unawaited(_events.close());
}

/// Grants the owner session to one client at a time.
final class OwnerSessions {
  OwnerSessions({required String Function() mintToken})
    : _mintToken = mintToken;

  final String Function() _mintToken;
  Owner? _owner;

  Owner? get owner => _owner;

  OwnerClaim claim({required int pid}) {
    final current = _owner;
    if (current != null) return OwnerRefused(ownerPid: current.pid);
    final owner = Owner(token: _mintToken(), pid: pid);
    _owner = owner;
    return OwnerGranted(owner);
  }

  /// Whether [token] is the current owner's.
  bool authorizes(String? token) => token != null && token == _owner?.token;

  void send(SessionEvent event) => _owner?.send(event);

  /// Ends [owner]'s session if it still holds it.
  void release(Owner owner) {
    if (!identical(owner, _owner)) return;
    _owner = null;
    owner._end();
  }
}

sealed class OwnerClaim {
  const OwnerClaim();
}

final class OwnerGranted extends OwnerClaim {
  const OwnerGranted(this.owner);

  final Owner owner;
}

final class OwnerRefused extends OwnerClaim {
  const OwnerRefused({required this.ownerPid});

  final int ownerPid;
}
