import 'package:win32_dart/src/bindings/windows_bindings.dart';
import 'package:win32_dart/src/constants.dart';

/// A Win32 `HANDLE` and the question every call site asks of one.
///
/// Failure sentinels are not uniform: `CreateFileW` returns
/// `INVALID_HANDLE_VALUE`, `GlobalAlloc` returns NULL.
extension type const Win32Handle(HANDLE raw) implements HANDLE {
  /// Whether the call that produced this handle succeeded.
  bool get isValid => address != 0 && address != invalidHandleAddress;
}
