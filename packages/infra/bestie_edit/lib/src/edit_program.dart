import 'dart:convert';

import 'package:bestie_edit/src/models/edit_reply.dart';
import 'package:bestie_edit/src/models/edit_request.dart';
import 'package:bestie_edit/src/models/edit_run.dart';
import 'package:process_host/process_host.dart';

/// Runs the `bestie_edit` program at [path] through [host], one request per
/// process: the request goes in as JSON on stdin, the reply comes back as
/// JSON on stdout.
class EditProgram {
  const EditProgram({
    required this.host,
    required this.path,
    this.environment = const {},
  });

  final ProcessHost host;

  /// Absolute path of the `bestie_edit` executable.
  final String path;

  /// The environment each run is given.
  final Map<String, String> environment;

  /// Performs [request], confined by [sandbox] when one is given.
  Future<EditRun> run(EditRequest request, {Sandbox? sandbox}) async =>
      switch (host.piped(
        executable: path,
        environment: environment,
        sandbox: sandbox,
      )) {
        ProcessSpawnFailed(:final failure) => EditProgramNotStarted(failure),
        ProcessSpawnSucceeded(:final process) => await _converse(
          process,
          request,
        ),
      };

  Future<EditRun> _converse(RunningProcess process, EditRequest request) async {
    final stdout = _collect(process.stdout);
    final stderr = _collect(process.stderr);
    process.writeString(request.toJson());
    await process.closeStdin();
    final exit = await process.exit;
    final answer = await stdout;
    final complaint = await stderr;
    await process.close();

    if (exit != const ProcessExited(0)) {
      return EditProgramFailed(exit: exit, stderr: complaint.trim());
    }
    try {
      return EditAnswered(EditReplyMapper.fromJson(answer));
    } on Object {
      return EditProgramGarbled(answer);
    }
  }

  static Future<String> _collect(Stream<List<int>> bytes) =>
      utf8.decoder.bind(bytes).join();
}
