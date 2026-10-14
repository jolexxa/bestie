// Runs `dart test` for the current package, surviving the race where another
// package's `dart test` rewrites the workspace native assets file mid-read.
//
// Usage (melos exec runs it in each package):
//   dart compile exe tool/test_package.dart -o .dart_tool/test_package.exe
//   .dart_tool/test_package.exe [dart test arguments]
import 'dart:io';

import 'src/dart_test.dart';

Future<void> main(List<String> arguments) async {
  exitCode = await runDartTest(
    arguments,
    workingDirectory: Directory.current.path,
  );
}
