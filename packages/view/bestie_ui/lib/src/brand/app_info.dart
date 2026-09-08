import 'package:intentions/intentions.dart';

/// What the Info page says about the binary it is running in, handed down at
/// bootstrap because the facts are the app's and the rendering is not.
@model
class AppInfo {
  const AppInfo({required this.version, required this.description});

  final String version;
  final String description;
}
