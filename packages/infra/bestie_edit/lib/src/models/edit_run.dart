import 'package:bestie_edit/src/models/edit_reply.dart';
import 'package:process_host/process_host.dart';

/// How one run of `bestie_edit` went: either it answered, or why it did not.
sealed class EditRun {
  const EditRun();
}

/// The program answered with [reply].
final class EditAnswered extends EditRun {
  const EditAnswered(this.reply);

  final EditReply reply;
}

/// The program produced no reply.
sealed class EditNotAnswered extends EditRun {
  const EditNotAnswered();
}

/// The program never started.
final class EditProgramNotStarted extends EditNotAnswered {
  const EditProgramNotStarted(this.failure);

  final SpawnFailure failure;
}

/// The program ended without answering, saying [stderr] on the way out.
final class EditProgramFailed extends EditNotAnswered {
  const EditProgramFailed({required this.exit, required this.stderr});

  final ProcessExit exit;
  final String stderr;
}

/// The program printed [stdout], which was not a reply.
final class EditProgramGarbled extends EditNotAnswered {
  const EditProgramGarbled(this.stdout);

  final String stdout;
}
