import 'dart:async';

import 'package:bestie_sandbox_use_case/src/sandbox_use_case.dart';
import 'package:intentions/intentions.dart';
import 'package:tool_protocol/tool_protocol.dart';

/// A write-access call as its job: open while the user is being asked,
/// settled by their answer, or canceled when the call is stopped first.
@PartOf(SandboxUseCase)
final class WriteAccessJob implements Job {
  /// [onStop] takes the ask back when the call is stopped before an answer.
  WriteAccessJob({required void Function() onStop}) : _onStop = onStop;

  final void Function() _onStop;
  final Completer<JobOutcome> _settled = Completer<JobOutcome>();
  JobOutcome? _outcome;

  @override
  JobOutcome? get outcome => _outcome;

  @override
  Future<JobOutcome> get settled => _settled.future;

  /// Never: the user's answer is the call's answer.
  @override
  Future<String> get inBackground => Completer<String>().future;

  /// Settles with [outcome]; later outcomes are dropped.
  void complete(JobOutcome outcome) {
    if (_settled.isCompleted) return;
    _outcome = outcome;
    _settled.complete(outcome);
  }

  @override
  void stop() {
    if (_settled.isCompleted) return;
    _onStop();
    complete(const JobCanceled('The write-access request was withdrawn.'));
  }
}
