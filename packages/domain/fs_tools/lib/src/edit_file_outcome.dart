import 'package:intentions/intentions.dart';
import 'package:tool_protocol/tool_protocol.dart';

/// What came of asking to edit the file at [path].
@model
sealed class EditFileOutcome {
  const EditFileOutcome(this.path);

  final String path;
}

/// The file was rewritten with [replacements] made.
@model
final class EditFileSucceeded extends EditFileOutcome {
  const EditFileSucceeded(
    super.path, {
    required this.replacements,
    required this.snippet,
    required this.diff,
  });

  final int replacements;

  /// The edited region with a few numbered lines either side.
  final String snippet;

  final FileDiff diff;
}

/// The text to find was not in the file.
@model
final class EditFileTargetMissing extends EditFileOutcome {
  const EditFileTargetMissing(super.path);
}

/// The text to find occurs [occurrences] times, and only one was asked for.
@model
final class EditFileAmbiguous extends EditFileOutcome {
  const EditFileAmbiguous(super.path, {required this.occurrences});

  final int occurrences;
}

/// The replacement would leave the file as it is.
@model
final class EditFileNoChange extends EditFileOutcome {
  const EditFileNoChange(super.path);
}

@model
final class EditFilePathMissing extends EditFileOutcome {
  const EditFilePathMissing(super.path);
}

@model
final class EditFileIsDirectory extends EditFileOutcome {
  const EditFileIsDirectory(super.path);
}

/// The file may not be read or written from where the editor runs.
@model
final class EditFileDenied extends EditFileOutcome {
  const EditFileDenied(super.path);
}

/// The file is not text.
@model
final class EditFileNotText extends EditFileOutcome {
  const EditFileNotText(super.path);
}

/// The editor itself could not answer, for [reason].
@model
final class EditFileEditorFailed extends EditFileOutcome {
  const EditFileEditorFailed(super.path, {required this.reason});

  final String reason;
}
