import 'package:intentions/intentions.dart';
import 'package:local_models_repository/src/models/local_model.dart';

@model
sealed class ScanOutput {
  const ScanOutput();
}

/// What a scan found, current as of the latest roots asked for.
@model
final class ScanPublished extends ScanOutput {
  const ScanPublished(this.models);

  final List<LocalModel> models;
}

/// The scan of the latest roots failed; whatever was published before
/// stands.
@model
final class ScanFailed extends ScanOutput {
  const ScanFailed(this.error);

  final String error;
}
