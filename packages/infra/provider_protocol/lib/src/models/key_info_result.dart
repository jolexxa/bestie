import 'package:provider_protocol/src/models/provider_failure.dart';
import 'package:provider_protocol/src/models/provider_key_info.dart';

/// The outcome of asking a provider about the API key in use.
sealed class KeyInfoResult {
  const KeyInfoResult();
}

final class KeyInfoFetched extends KeyInfoResult {
  const KeyInfoFetched(this.keyInfo);

  final ProviderKeyInfo keyInfo;
}

final class KeyInfoFailed extends KeyInfoResult {
  const KeyInfoFailed(this.failure);

  final ProviderFailure failure;
}

/// The provider has no notion of key metadata.
final class KeyInfoUnsupported extends KeyInfoResult {
  const KeyInfoUnsupported();
}
