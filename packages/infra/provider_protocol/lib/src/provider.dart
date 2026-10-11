import 'package:provider_protocol/src/models/provider_credentials.dart';
import 'package:provider_protocol/src/models/provider_credentials_kind.dart';
import 'package:provider_protocol/src/provider_connection.dart';

/// A provider bestie ships: what it is called, what it asks the user for,
/// and how to reach it.
abstract interface class Provider {
  /// Stable identifier, e.g. `openrouter`.
  String get id;

  String get displayName;

  ProviderCredentialsKind get credentialsKind;

  /// A connection that reaches the provider with [credentials]. Every
  /// provider accepts [NoCredentials] and lists what it can without them.
  ProviderConnection connect(ProviderCredentials credentials);
}
