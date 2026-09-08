import 'package:process_host/src/winsize.dart';

/// The host terminal's window size, and a stream of changes to it.
abstract interface class HostWinsizeSource {
  /// The host terminal's size right now, or a sensible default when no
  /// terminal is attached.
  Winsize get current;

  /// Emits the host terminal's size whenever it changes.
  Stream<Winsize> get changes;
}
