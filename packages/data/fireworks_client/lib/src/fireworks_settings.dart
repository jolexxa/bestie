import 'package:intentions/intentions.dart';
import 'package:meta/meta.dart';

/// What the user gave us to reach Fireworks AI.
@model
@immutable
final class FireworksSettings {
  const FireworksSettings({required this.apiKey});

  /// Nothing has been given yet.
  static const unset = FireworksSettings(apiKey: '');

  final String apiKey;

  bool get isSet => apiKey.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      other is FireworksSettings && other.apiKey == apiKey;

  @override
  int get hashCode => apiKey.hashCode;

  /// Never prints the key.
  @override
  String toString() => 'FireworksSettings(apiKey: ${isSet ? 'set' : 'unset'})';
}
