import 'package:meta/meta.dart';

/// Why a provider account call did not produce a usable result.
@immutable
sealed class ProviderFailure {
  const ProviderFailure._(this._name, this.message);

  /// The failure an HTTP error [statusCode] stands for.
  factory ProviderFailure.forStatus(int statusCode, String message) =>
      switch (statusCode) {
        401 || 403 => ProviderAuthFailed(message),
        429 => ProviderRateLimited(message),
        >= 500 => ProviderServerFailed(message),
        _ => ProviderRejected(message),
      };

  final String _name;

  final String message;

  @override
  bool operator ==(Object other) =>
      other.runtimeType == runtimeType &&
      other is ProviderFailure &&
      other.message == message;

  @override
  int get hashCode => Object.hash(runtimeType, message);

  @override
  String toString() => '$_name($message)';
}

/// The provider refused the credentials.
final class ProviderAuthFailed extends ProviderFailure {
  const ProviderAuthFailed(String message)
    : super._('ProviderAuthFailed', message);
}

/// The provider asked to slow down.
final class ProviderRateLimited extends ProviderFailure {
  const ProviderRateLimited(String message)
    : super._('ProviderRateLimited', message);
}

/// The provider could not be reached.
final class ProviderUnreachable extends ProviderFailure {
  const ProviderUnreachable(String message)
    : super._('ProviderUnreachable', message);
}

/// The provider refused the request itself.
final class ProviderRejected extends ProviderFailure {
  const ProviderRejected(String message) : super._('ProviderRejected', message);
}

/// The provider failed on its side.
final class ProviderServerFailed extends ProviderFailure {
  const ProviderServerFailed(String message)
    : super._('ProviderServerFailed', message);
}

/// The provider answered with something unreadable.
final class ProviderResponseMalformed extends ProviderFailure {
  const ProviderResponseMalformed(String message)
    : super._('ProviderResponseMalformed', message);
}

/// The call was given up before it finished.
final class ProviderCancelled extends ProviderFailure {
  const ProviderCancelled(String message)
    : super._('ProviderCancelled', message);
}

/// The provider is held by another client until it lets go.
final class ProviderOccupied extends ProviderFailure {
  const ProviderOccupied(String message) : super._('ProviderOccupied', message);
}
