import 'package:bestie_edit/bestie_edit.dart';
import 'package:edit_data_source/edit_data_source.dart';
import 'package:fs_tools/src/create_file_outcome.dart';
import 'package:fs_tools/src/edit_file_outcome.dart';
import 'package:intentions/intentions.dart';
import 'package:process_host/process_host.dart';

/// The filesystem tools a model may call: making a file and editing one in
/// place. Reading, listing and searching are shell commands.
@repository
class FsTools {
  const FsTools({required EditDataSource editor}) : _editor = editor;

  final EditDataSource _editor;

  /// Replaces [oldText] with [newText] in the file at [path]. [oldText] must
  /// occur exactly once unless [replaceAll]. The edit runs under [sandbox]
  /// when one is given.
  Future<EditFileOutcome> editFile({
    required String path,
    required String oldText,
    required String newText,
    bool replaceAll = false,
    Sandbox? sandbox,
  }) async {
    final run = await _editor.edit(
      ReplaceRequest(
        path: path,
        oldText: oldText,
        newText: newText,
        replaceAll: replaceAll,
      ),
      sandbox: sandbox,
    );
    return switch (run) {
      EditAnswered(:final reply) => _editOutcomeOf(path, reply),
      EditNotAnswered() => EditFileEditorFailed(
        path,
        reason: _failureReason(run),
      ),
    };
  }

  /// Makes a new file at [path] holding [contents], parents included. The
  /// write runs under [sandbox] when one is given.
  Future<CreateFileOutcome> createFile({
    required String path,
    required String contents,
    Sandbox? sandbox,
  }) async {
    final run = await _editor.edit(
      CreateRequest(path: path, contents: contents),
      sandbox: sandbox,
    );
    return switch (run) {
      EditAnswered(:final reply) => _createOutcomeOf(path, reply),
      EditNotAnswered() => CreateFileEditorFailed(
        path,
        reason: _failureReason(run),
      ),
    };
  }

  EditFileOutcome _editOutcomeOf(String path, EditReply reply) =>
      switch (reply) {
        EditSucceeded(:final replacements, :final snippet, :final diff) =>
          EditFileSucceeded(
            path,
            replacements: replacements,
            snippet: snippet,
            diff: diff,
          ),
        EditTargetMissing() => EditFileTargetMissing(path),
        EditAmbiguous(:final occurrences) => EditFileAmbiguous(
          path,
          occurrences: occurrences,
        ),
        EditNoChange() => EditFileNoChange(path),
        EditPathMissing() => EditFilePathMissing(path),
        EditIsDirectory() => EditFileIsDirectory(path),
        EditDenied() => EditFileDenied(path),
        EditNotText() => EditFileNotText(path),
        EditCreated() || EditPathExists() => EditFileEditorFailed(
          path,
          reason: _outOfTurn,
        ),
      };

  CreateFileOutcome _createOutcomeOf(String path, EditReply reply) =>
      switch (reply) {
        EditCreated() => CreateFileSucceeded(path),
        EditPathExists() || EditIsDirectory() => CreateFilePathExists(path),
        EditDenied() => CreateFileDenied(path),
        EditSucceeded() ||
        EditTargetMissing() ||
        EditAmbiguous() ||
        EditNoChange() ||
        EditPathMissing() ||
        EditNotText() => CreateFileEditorFailed(path, reason: _outOfTurn),
      };

  /// Why a run that never produced a reply came to nothing.
  String _failureReason(EditNotAnswered run) => switch (run) {
    EditProgramNotStarted(:final failure) =>
      'the editor could not be started: ${failure.message}',
    EditProgramFailed(:final exit, :final stderr) =>
      stderr.isEmpty ? 'the editor ended with $exit' : stderr,
    EditProgramGarbled() => 'the editor answered with something unreadable',
  };

  static const _outOfTurn = 'the editor answered out of turn';
}
