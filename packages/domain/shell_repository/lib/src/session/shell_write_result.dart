import 'package:intentions/intentions.dart';

/// Outcome of writing to a shell session's stdin.
@model
sealed class ShellWriteResult {
  const ShellWriteResult();
}

/// The bytes were handed to the child.
@model
final class ShellWriteAccepted extends ShellWriteResult {
  const ShellWriteAccepted();
}

/// The session would not take the bytes; [reason] says why.
@model
final class ShellWriteRefused extends ShellWriteResult {
  const ShellWriteRefused(this.reason);

  /// Human-readable refusal description.
  final String reason;
}
