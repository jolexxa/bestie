import 'package:win32_dart/src/bindings/windows_bindings.dart';
import 'package:win32_dart/src/text.dart';
import 'package:win32_dart/src/win32_failure.dart';

/// The directory Windows searches when a loaded DLL pulls in its own
/// dependencies.
class DllSearchPath {
  DllSearchPath(this._bindings);

  final WindowsBindings _bindings;

  /// Searches [directory], replacing whatever a previous call named. Windows
  /// keeps one such directory per process, not a list.
  DllSearchPathResult use(String directory) {
    final ok = withWideString(directory, _bindings.SetDllDirectoryW);
    if (ok == 0) {
      return DllSearchPathFailed(
        Win32Failure.fromLastError(_bindings, 'SetDllDirectoryW'),
      );
    }
    return const DllSearchPathSucceeded();
  }
}

sealed class DllSearchPathResult {
  const DllSearchPathResult();
}

final class DllSearchPathSucceeded extends DllSearchPathResult {
  const DllSearchPathSucceeded();
}

final class DllSearchPathFailed extends DllSearchPathResult {
  const DllSearchPathFailed(this.failure);
  final Win32Failure failure;
}
