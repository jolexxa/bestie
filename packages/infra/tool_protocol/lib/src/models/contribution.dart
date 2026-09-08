import 'package:dart_mappable/dart_mappable.dart';
import 'package:tool_protocol/src/models/file_diff.dart';

part 'contribution.mapper.dart';

/// Something a tool call produced besides its answer: kept with the call,
/// shown to the user, never sent to the model.
@MappableClass(discriminatorKey: 'type')
sealed class Contribution with ContributionMappable {
  const Contribution();

  String get type;
}

@MappableClass(discriminatorValue: 'source')
final class SourceContribution extends Contribution
    with SourceContributionMappable {
  const SourceContribution({required this.url, this.title});

  final String url;
  final String? title;

  @override
  String get type => 'source';
}

/// The change a call made to the file at [path].
@MappableClass(discriminatorValue: 'diff')
final class DiffContribution extends Contribution
    with DiffContributionMappable {
  const DiffContribution({required this.path, required this.diff});

  final String path;
  final FileDiff diff;

  @override
  String get type => 'diff';
}

/// The file a call brought into being at [path]. [lines] counts the whole
/// file even when [truncated] dropped the tail of [text].
@MappableClass(discriminatorValue: 'created')
final class CreatedFileContribution extends Contribution
    with CreatedFileContributionMappable {
  const CreatedFileContribution({
    required this.path,
    required this.text,
    required this.lines,
    this.truncated = false,
  });

  final String path;
  final String text;
  final int lines;
  final bool truncated;

  @override
  String get type => 'created';
}
