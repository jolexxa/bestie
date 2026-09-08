import 'package:intentions/intentions.dart';

/// What came of asking to create the file at [path].
@model
sealed class CreateFileOutcome {
  const CreateFileOutcome(this.path);

  final String path;
}

@model
final class CreateFileSucceeded extends CreateFileOutcome {
  const CreateFileSucceeded(super.path);
}

/// Something is already at the path.
@model
final class CreateFilePathExists extends CreateFileOutcome {
  const CreateFilePathExists(super.path);
}

/// The file may not be made from where the editor runs.
@model
final class CreateFileDenied extends CreateFileOutcome {
  const CreateFileDenied(super.path);
}

/// The editor itself could not answer, for [reason].
@model
final class CreateFileEditorFailed extends CreateFileOutcome {
  const CreateFileEditorFailed(super.path, {required this.reason});

  final String reason;
}
