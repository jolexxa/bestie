import 'package:bestie_platform_abstractions/bestie_platform_abstractions.dart';
import 'package:intentions/intentions.dart';
import 'package:win32_dart/win32_dart.dart';

/// Copies through Win32 rather than a helper process, which is what keeps
/// this package free of a process dependency.
@dataSource
class WindowsClipboardDataSource implements ClipboardDataSource {
  /// [clipboard] defaults to the host's Win32 surface; pass one to
  /// substitute a double.
  WindowsClipboardDataSource({Clipboard? clipboard})
    : _clipboard = clipboard ?? Clipboard(win32);

  final Clipboard _clipboard;

  @override
  Future<void> copy(String text) async {
    // The clipboard is exclusive process-wide, so a failure here means
    // another process is holding it. Copy is best-effort on every platform;
    // the shell-out implementations swallow the same class of failure.
    if (_clipboard.open() case ClipboardOpenSucceeded(:final session)) {
      session
        ..writeUnicodeText(text)
        ..close();
    }
  }
}
