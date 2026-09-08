import 'dart:async';

import 'package:tool_protocol/src/models/contribution.dart';

/// Work started by one tool call. A call may finish before its job does.
abstract interface class Job {
  factory Job.done(String content, {List<Contribution> contributions}) =
      _CompletedJob.succeeded;

  factory Job.failed(String message, {String content}) = _CompletedJob.failed;

  /// Asks the feature to stop this work. It is always fire-and-forget.
  void stop();

  /// Null until the job has settled.
  JobOutcome? get outcome;

  /// The job's one eventual outcome.
  Future<JobOutcome> get settled;

  /// Completes only when the feature hands the call back while work continues.
  Future<String> get inBackground;
}

/// The terminal outcome of a [Job].
sealed class JobOutcome {
  const JobOutcome();
}

/// Work completed successfully.
base class JobSucceeded extends JobOutcome {
  const JobSucceeded(this.content, {this.contributions = const []});

  final String content;
  final List<Contribution> contributions;
}

/// Work failed, optionally after producing output.
base class JobFailed extends JobOutcome {
  const JobFailed(this.message, {this.content = ''});

  final String message;
  final String content;
}

/// Work was deliberately stopped.
base class JobCanceled extends JobFailed {
  const JobCanceled(super.message, {super.content});
}

final class _CompletedJob implements Job {
  _CompletedJob.succeeded(
    String content, {
    List<Contribution> contributions = const [],
  }) : _outcome = JobSucceeded(content, contributions: contributions);

  _CompletedJob.failed(String message, {String content = ''})
    : _outcome = JobFailed(message, content: content);

  final JobOutcome _outcome;

  @override
  JobOutcome get outcome => _outcome;

  @override
  Future<JobOutcome> get settled => Future.value(_outcome);

  @override
  Future<String> get inBackground => Completer<String>().future;

  @override
  void stop() {}
}
