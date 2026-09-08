import 'package:intentions/intentions.dart';
import 'package:provider_protocol/provider_protocol.dart';
import 'package:provider_repository/provider_repository.dart';
import 'package:sandbox_repository/sandbox_repository.dart';

@model
class StatusBarData {
  StatusBarData({
    required this.status,
    required this.credits,
    required this.sandbox,
  });

  ProviderStatus status;
  CreditsResult? credits;

  /// How far along the session's sandbox is since startup.
  SandboxReadiness sandbox;

  /// Whether the primary conversation was mid-turn at the last look.
  bool turnInFlight = false;
}
