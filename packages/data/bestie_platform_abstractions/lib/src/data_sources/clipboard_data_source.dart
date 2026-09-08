import 'package:intentions/intentions.dart';

/// External clipboard writer.
@dataSource
// This is a platform abstraction interface, not a utility function.
// ignore: one_member_abstracts
abstract interface class ClipboardDataSource {
  /// Copies [text] to the system clipboard.
  Future<void> copy(String text);
}
