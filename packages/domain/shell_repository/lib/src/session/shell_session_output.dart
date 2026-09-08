import 'package:intentions/intentions.dart';

/// Outputs emitted by one shell session's state machine.
@model
sealed class ShellSessionOutput {
  const ShellSessionOutput();
}

/// The session's state changed; subscribers should re-read it. This is what
/// `ShellSession` turns into a stream event.
@model
final class ShellSessionChanged extends ShellSessionOutput {
  const ShellSessionChanged();
}
