import 'package:bestie_edit/bestie_edit.dart';
import 'package:intentions/intentions.dart';
import 'package:process_host/process_host.dart';

/// Edits files by running the `bestie_edit` program, so every write goes
/// through the same confinement as a shell command.
@dataSource
class EditDataSource {
  const EditDataSource({required EditProgram program}) : _program = program;

  final EditProgram _program;

  /// Performs [request], confined by [sandbox] when one is given.
  Future<EditRun> edit(EditRequest request, {Sandbox? sandbox}) =>
      _program.run(request, sandbox: sandbox);
}
