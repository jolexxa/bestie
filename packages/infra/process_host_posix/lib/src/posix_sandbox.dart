import 'dart:typed_data';

import 'package:process_host/process_host.dart';

/// A confinement the native supervisor applies in the forked child, before
/// `exec`, by reading [confineProgram] off an inherited fd.
abstract interface class PosixSandbox implements Sandbox {
  /// The lowered grant program the child confines itself with.
  Uint8List get confineProgram;
}
