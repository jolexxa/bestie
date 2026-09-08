import 'package:intentions/intentions.dart';

/// The Windows console host bestie ships: Microsoft's redistributable
/// `conpty.dll` and the `OpenConsole.exe` it launches.
@model
class ConsoleHost {
  const ConsoleHost({required this.libraryPath, required this.executablePath});

  /// Absolute path of `conpty.dll`, used for its pseudoconsole
  /// entry points.
  final String libraryPath;

  /// Absolute path of the `OpenConsole.exe` the library launches.
  final String executablePath;
}
