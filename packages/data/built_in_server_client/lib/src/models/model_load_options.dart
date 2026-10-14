import 'package:intentions/intentions.dart';
import 'package:meta/meta.dart';

/// How the built-in server is asked to load every model, as configured.
@model
@immutable
final class ModelLoadOptions {
  const ModelLoadOptions({this.contextCap});

  /// Nothing has been configured: the server decides everything itself.
  static const defaults = ModelLoadOptions();

  /// The most context to run a model with; null for as much as fits.
  final int? contextCap;

  @override
  bool operator ==(Object other) =>
      other is ModelLoadOptions && other.contextCap == contextCap;

  @override
  int get hashCode => contextCap.hashCode;

  @override
  String toString() => 'ModelLoadOptions(contextCap: $contextCap)';
}
