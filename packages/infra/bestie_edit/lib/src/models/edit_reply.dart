import 'package:dart_mappable/dart_mappable.dart';
import 'package:tool_protocol/tool_protocol.dart';

part 'edit_reply.mapper.dart';

/// What `bestie_edit` said became of a request.
@MappableClass(discriminatorKey: 'outcome')
sealed class EditReply with EditReplyMappable {
  const EditReply();
}

/// The file was rewritten.
@MappableClass(discriminatorValue: 'succeeded')
final class EditSucceeded extends EditReply with EditSucceededMappable {
  const EditSucceeded({
    required this.replacements,
    required this.snippet,
    required this.diff,
  });

  final int replacements;

  /// The edited region with a few numbered lines either side.
  final String snippet;

  final FileDiff diff;
}

/// The file was brought into being.
@MappableClass(discriminatorValue: 'created')
final class EditCreated extends EditReply with EditCreatedMappable {
  const EditCreated();
}

/// The text to find was not in the file.
@MappableClass(discriminatorValue: 'targetMissing')
final class EditTargetMissing extends EditReply with EditTargetMissingMappable {
  const EditTargetMissing();
}

/// The text to find occurs more than once and the request did not say to
/// replace them all.
@MappableClass(discriminatorValue: 'ambiguous')
final class EditAmbiguous extends EditReply with EditAmbiguousMappable {
  const EditAmbiguous({required this.occurrences});

  final int occurrences;
}

/// The replacement would leave the file as it is.
@MappableClass(discriminatorValue: 'noChange')
final class EditNoChange extends EditReply with EditNoChangeMappable {
  const EditNoChange();
}

@MappableClass(discriminatorValue: 'pathMissing')
final class EditPathMissing extends EditReply with EditPathMissingMappable {
  const EditPathMissing();
}

/// Something is already at the path a new file was to be made at.
@MappableClass(discriminatorValue: 'pathExists')
final class EditPathExists extends EditReply with EditPathExistsMappable {
  const EditPathExists();
}

@MappableClass(discriminatorValue: 'isDirectory')
final class EditIsDirectory extends EditReply with EditIsDirectoryMappable {
  const EditIsDirectory();
}

/// The file could not be read or written; under a sandbox, this is how a
/// refusal surfaces.
@MappableClass(discriminatorValue: 'denied')
final class EditDenied extends EditReply with EditDeniedMappable {
  const EditDenied();
}

/// The file is not UTF-8 text.
@MappableClass(discriminatorValue: 'notText')
final class EditNotText extends EditReply with EditNotTextMappable {
  const EditNotText();
}
