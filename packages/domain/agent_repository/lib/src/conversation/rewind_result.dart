import 'package:intentions/intentions.dart';

/// Outcome of cutting the primary session's history back to just before one
/// of the user's messages.
@model
sealed class RewindResult {
  const RewindResult();
}

/// The history now ends just before the message, whose text is handed back
/// so it can be edited and sent again.
@model
final class Rewound extends RewindResult {
  const Rewound({required this.message});

  final String message;
}

/// No user message carries that id.
@model
final class RewindTargetNotFound extends RewindResult {
  const RewindTargetNotFound();
}
