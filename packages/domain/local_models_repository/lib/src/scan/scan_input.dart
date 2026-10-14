import 'package:intentions/intentions.dart';
import 'package:local_models_repository/src/models/local_model.dart';

@model
sealed class ScanInput {
  const ScanInput();
}

/// Scan [roots], or scan again once the scan under way finishes, dropping
/// what that one finds.
@model
final class RescanRequested extends ScanInput {
  const RescanRequested(this.roots);

  final List<String> roots;
}

@model
final class ScanFinished extends ScanInput {
  const ScanFinished(this.models);

  final List<LocalModel> models;
}

/// The scan threw rather than answering.
@model
final class ScanThrew extends ScanInput {
  const ScanThrew(this.error);

  final Object error;
}
