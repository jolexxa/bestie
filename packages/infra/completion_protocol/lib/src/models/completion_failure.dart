import 'package:meta/meta.dart';

/// The broad category of a failed completion.
enum CompletionFailureKind {
  network,
  auth,
  rateLimit,
  badRequest,
  server,
  malformedResponse,
  cancelled,
}

/// Why a remote request did not produce a usable result.
@immutable
final class CompletionFailure {
  const CompletionFailure({required this.kind, required this.message});

  final CompletionFailureKind kind;

  final String message;

  @override
  bool operator ==(Object other) =>
      other is CompletionFailure &&
      other.kind == kind &&
      other.message == message;

  @override
  int get hashCode => Object.hash(kind, message);

  @override
  String toString() => 'CompletionFailure(${kind.name}): $message';
}
