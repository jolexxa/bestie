import 'package:win32_dart/src/bindings/windows_bindings.dart';
import 'package:win32_dart/src/win32_failure.dart';

/// Reads the logical processor count via `GetActiveProcessorCount`.
class ProcessorQuery {
  ProcessorQuery(this._bindings);

  final WindowsBindings _bindings;

  /// Counts active logical processors across every processor group.
  ProcessorCountResult activeCount() {
    final count = _bindings.GetActiveProcessorCount(ALL_PROCESSOR_GROUPS);
    if (count == 0) {
      return ProcessorCountFailed(
        Win32Failure.fromLastError(_bindings, 'GetActiveProcessorCount'),
      );
    }
    return ProcessorCountSucceeded(count);
  }
}

sealed class ProcessorCountResult {
  const ProcessorCountResult();
}

final class ProcessorCountSucceeded extends ProcessorCountResult {
  const ProcessorCountSucceeded(this.count);
  final int count;
}

final class ProcessorCountFailed extends ProcessorCountResult {
  const ProcessorCountFailed(this.failure);
  final Win32Failure failure;
}
