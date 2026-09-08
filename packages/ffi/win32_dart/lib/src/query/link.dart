import 'dart:ffi';

import 'package:win32_dart/src/bindings/windows_bindings.dart';
import 'package:win32_dart/src/text.dart';
import 'package:win32_dart/src/win32_failure.dart';

/// Creates NTFS hardlinks via `CreateHardLinkW`.
class HardLinkQuery {
  HardLinkQuery(this._bindings);

  final WindowsBindings _bindings;

  /// Creates a hardlink at [linkPath] that refers to the existing
  /// [targetPath]. Both must sit on the same volume — a coreutils multicall
  /// and its dispatch names always do.
  HardLinkResult create({
    required String linkPath,
    required String targetPath,
  }) {
    final ok = withWideString(
      linkPath,
      (link) => withWideString(
        targetPath,
        (target) => _bindings.CreateHardLinkW(link, target, nullptr),
      ),
    );
    if (ok == 0) {
      return HardLinkFailed(
        Win32Failure.fromLastError(_bindings, 'CreateHardLinkW'),
      );
    }
    return const HardLinkSucceeded();
  }
}

sealed class HardLinkResult {
  const HardLinkResult();
}

final class HardLinkSucceeded extends HardLinkResult {
  const HardLinkSucceeded();
}

final class HardLinkFailed extends HardLinkResult {
  const HardLinkFailed(this.failure);
  final Win32Failure failure;
}
