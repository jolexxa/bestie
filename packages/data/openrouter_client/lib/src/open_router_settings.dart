import 'package:intentions/intentions.dart';
import 'package:meta/meta.dart';

/// What the user gave us to reach OpenRouter.
@model
@immutable
final class OpenRouterSettings {
  const OpenRouterSettings({required this.apiKey});

  /// Nothing has been given yet.
  static const unset = OpenRouterSettings(apiKey: '');

  final String apiKey;

  bool get isSet => apiKey.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      other is OpenRouterSettings && other.apiKey == apiKey;

  @override
  int get hashCode => apiKey.hashCode;

  /// Never prints the key.
  @override
  String toString() => 'OpenRouterSettings(apiKey: ${isSet ? 'set' : 'unset'})';
}
