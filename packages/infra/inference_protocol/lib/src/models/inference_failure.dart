import 'package:meta/meta.dart';

/// The broad category of a remote inference failure.
enum InferenceFailureKind {
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
final class InferenceFailure {
  const InferenceFailure({required this.kind, required this.message});

  final InferenceFailureKind kind;

  final String message;

  @override
  bool operator ==(Object other) =>
      other is InferenceFailure &&
      other.kind == kind &&
      other.message == message;

  @override
  int get hashCode => Object.hash(kind, message);

  @override
  String toString() => 'InferenceFailure(${kind.name}): $message';
}
