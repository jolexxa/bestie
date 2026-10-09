import 'package:intentions/intentions.dart';

/// How the `local` provider runs a model it activates.
@model
final class LocalProviderOptions {
  const LocalProviderOptions({this.contextCap});

  /// The most context to run a model with; null for as much as fits.
  final int? contextCap;
}

/// Reads the options the user set, as they stand right now.
typedef LocalProviderOptionsReader = LocalProviderOptions Function();
