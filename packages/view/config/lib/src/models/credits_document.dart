import 'package:intentions/intentions.dart';

/// The attribution document (`CREDITS.md`) loaded at bootstrap from the
/// bundled asset the platform layer resolves, surfaced to the Credits
/// page of the config overlay.
@model
class CreditsDocument {
  const CreditsDocument({required this.markdown});

  /// Raw markdown source of `CREDITS.md`.
  final String markdown;
}
