import 'package:provider_protocol/src/models/provider_credits.dart';
import 'package:provider_protocol/src/models/provider_failure.dart';

/// The outcome of asking a provider for the account balance.
sealed class CreditsResult {
  const CreditsResult();
}

final class CreditsFetched extends CreditsResult {
  const CreditsFetched(this.credits);

  final ProviderCredits credits;
}

final class CreditsFailed extends CreditsResult {
  const CreditsFailed(this.failure);

  final ProviderFailure failure;
}

/// The provider has no notion of a balance.
final class CreditsUnsupported extends CreditsResult {
  const CreditsUnsupported();
}
