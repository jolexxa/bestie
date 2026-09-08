import 'package:bestie_sandbox_use_case/bestie_sandbox_use_case.dart';
import 'package:intentions/intentions.dart';
import 'package:sandbox_repository/sandbox_repository.dart';

/// What the composer slot shows.
@model
sealed class ComposerMode {
  const ComposerMode();
}

/// The text field: the user may type and send.
@model
final class Composing extends ComposerMode {
  const Composing();
}

/// Nothing: the agent at hand is read-only.
@model
final class ReadOnlyComposer extends ComposerMode {
  const ReadOnlyComposer();
}

/// The rewind hint: the user is picking a message to cut back to.
@model
final class RewindingComposer extends ComposerMode {
  const RewindingComposer();
}

/// The write-access prompt: an agent asks to write under a directory and
/// the user answers.
@model
final class WriteAccessPrompt extends ComposerMode {
  const WriteAccessPrompt(this.request);

  final WriteAccessRequest request;
}

/// The sandbox gate, showing where [readiness] stands.
@model
final class SandboxGate extends ComposerMode {
  const SandboxGate(this.readiness);

  final SandboxReadiness readiness;

  /// Whether Enter initializes (or retries).
  bool get acceptsEnter =>
      readiness is SandboxAwaitingInitialization ||
      readiness is SandboxInitializationFailed;
}
