import 'package:bestie/src/app/models/bestie_version.dart';
import 'package:intentions/intentions.dart';

/// Static, build-time facts about the bestie binary.
@model
class AppMetadata {
  const AppMetadata._();

  /// The bestie version. Written into `bestie_version.dart` by
  /// `tool/set_version.dart` during release builds; `0.0.0` for local
  /// development.
  static const String version = bestieVersion;

  static const String executableName = 'bestie';
  static const String packageName = 'bestie';
  static const String description = 'An humble AI in your terminal.';
  static const String title = 'Bestie 🥺';
}
