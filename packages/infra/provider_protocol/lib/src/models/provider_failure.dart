import 'package:inference_protocol/inference_protocol.dart';
import 'package:meta/meta.dart';

/// Why a provider account call did not produce a usable result.
@immutable
final class ProviderFailure {
  const ProviderFailure({required this.kind, required this.message});

  final InferenceFailureKind kind;

  final String message;

  @override
  bool operator ==(Object other) =>
      other is ProviderFailure &&
      other.kind == kind &&
      other.message == message;

  @override
  int get hashCode => Object.hash(kind, message);

  @override
  String toString() => 'ProviderFailure(${kind.name}): $message';
}
