import 'dart:async';

import 'package:bestie_sandbox_use_case/src/sandbox_use_case.dart';
import 'package:bestie_sandbox_use_case/src/write_access_request.dart';
import 'package:intentions/intentions.dart';
import 'package:rxdart/subjects.dart';

/// How an ask left the queue.
enum WriteAccessAnswer {
  /// The user said yes.
  allowed,

  /// The user said no.
  declined,

  /// The ask was taken back before the user answered.
  withdrawn,
}

/// The asks awaiting the user, put to them one at a time in the order they
/// came.
@PartOf(SandboxUseCase)
final class WriteAccessQueue {
  final List<_Pending> _pending = [];
  final BehaviorSubject<WriteAccessRequest?> _head = BehaviorSubject.seeded(
    null,
  );

  /// The ask in front of the user, or null when there is none.
  WriteAccessRequest? get current => _head.value;

  /// [current] as it moves, opening with the current value.
  Stream<WriteAccessRequest?> get stream => _head.stream;

  /// Puts [request] in line and answers with how it left.
  Future<WriteAccessAnswer> enqueue(WriteAccessRequest request) {
    final pending = _Pending(request);
    _pending.add(pending);
    _publish();
    return pending.answer.future;
  }

  /// The user's answer to the ask [id]; ignored for an ask no longer waiting.
  void answer(String id, {required bool allow}) => _settle(
    id,
    allow ? WriteAccessAnswer.allowed : WriteAccessAnswer.declined,
  );

  /// Takes the ask [id] back before the user answers.
  void withdraw(String id) => _settle(id, WriteAccessAnswer.withdrawn);

  Future<void> dispose() => _head.close();

  void _settle(String id, WriteAccessAnswer answer) {
    final index = _pending.indexWhere((pending) => pending.request.id == id);
    if (index < 0) return;
    _pending.removeAt(index).answer.complete(answer);
    _publish();
  }

  void _publish() {
    final head = _pending.firstOrNull?.request;
    if (_head.isClosed || _head.value == head) return;
    _head.add(head);
  }
}

final class _Pending {
  _Pending(this.request);

  final WriteAccessRequest request;
  final Completer<WriteAccessAnswer> answer = Completer<WriteAccessAnswer>();
}
