import 'package:dart_mappable/dart_mappable.dart';
import 'package:intentions/intentions.dart';
import 'package:provider_protocol/provider_protocol.dart' show ProviderModelRef;
import 'package:provider_protocol/provider_protocol_mappers.dart';
import 'package:provider_repository/src/models/provider_account.dart';

part 'provider_settings.mapper.dart';

/// What the user asked to run against: which accounts, which model, how
/// many agents at once.
@model
@MappableClass(generateMethods: GenerateMethods.equals | GenerateMethods.copy)
final class ProviderSettings with ProviderSettingsMappable {
  const ProviderSettings({
    required this.accounts,
    required this.model,
    required this.maxAgents,
  });

  final List<ProviderAccount> accounts;

  final ProviderModelRef? model;

  final int maxAgents;

  bool get hasUsableAccount => accounts.any((account) => account.isUsable);

  ProviderAccount? accountFor(String providerId) => accounts
      .where((account) => account.descriptor.id == providerId)
      .firstOrNull;

  /// Whether there is enough here to attempt a connection.
  bool get isComplete => model != null && maxAgents > 0 && hasUsableAccount;

  /// Never prints a key.
  @override
  String toString() =>
      'ProviderSettings(model: ${model?.qualified}, maxAgents: $maxAgents, '
      'accounts: $accounts)';
}
