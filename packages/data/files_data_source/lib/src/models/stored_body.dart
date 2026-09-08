import 'package:intentions/intentions.dart';
import 'package:tool_protocol/tool_protocol.dart';

/// Text that was written somewhere in full, of which only the head was kept.
@model
final class StoredBody {
  const StoredBody({
    required this.head,
    required this.totalChars,
    required this.storedAt,
  });

  /// As much of the beginning as the allowance kept, placed in the whole.
  final Excerpt<LinePlace> head;

  /// Characters written.
  final int totalChars;

  /// Absolute path everything was written to.
  final String storedAt;

  /// Lines written.
  int get totalLines => head.extent.tally;
}
