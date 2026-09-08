import 'package:dart_mappable/dart_mappable.dart';

part 'edit_request.mapper.dart';

/// What `bestie_edit` is asked to do to one file.
@MappableClass(discriminatorKey: 'action')
sealed class EditRequest with EditRequestMappable {
  const EditRequest();

  String get path;
}

/// One exact-string replacement in an existing file.
@MappableClass(discriminatorValue: 'edit')
final class ReplaceRequest extends EditRequest with ReplaceRequestMappable {
  const ReplaceRequest({
    required this.path,
    required this.oldText,
    required this.newText,
    this.replaceAll = false,
  });

  @override
  final String path;

  /// The text to find. Must occur exactly once unless [replaceAll].
  @MappableField(key: 'old')
  final String oldText;

  /// The text to put in its place.
  @MappableField(key: 'new')
  final String newText;

  final bool replaceAll;
}

/// A new file holding [contents], with any missing parent directories made
/// on the way.
@MappableClass(discriminatorValue: 'create')
final class CreateRequest extends EditRequest with CreateRequestMappable {
  const CreateRequest({required this.path, required this.contents});

  @override
  final String path;

  final String contents;
}
