part of 'sequence_scheduler.dart';

const int adaptiveStepMinimumSampleRows = 1;
const int adaptiveStepMinimumMixedPrefillRows = 0;
const int adaptiveStepMinimumSoloPrefillRows = 1;
const int adaptiveStepDefaultFailureShrinkNumerator = 1;
const int adaptiveStepDefaultFailureShrinkDenominator = 2;
const Duration adaptiveStepDefaultTargetTime = Duration(milliseconds: 50);

final class StepAdmissionBudget {
  const StepAdmissionBudget({
    required this.maxSampleRows,
    required this.maxPrefillRows,
  });

  final int maxSampleRows;

  final int maxPrefillRows;
}

final class StepBatchShape {
  const StepBatchShape({required this.sampleRows, required this.prefillRows});

  final int sampleRows;
  final int prefillRows;

  bool get isMixed => sampleRows > 0;

  bool get hasWork => sampleRows > 0 || prefillRows > 0;
}

/// Sizes each step's batch: it shrinks the batch after the backend runs out
/// of KV slots, and, while other sequences wait to decode, caps prefill rows
/// so a step lands near [targetStepTime]. One long prompt then never stalls
/// every other agent's decode, yet prefills at full batch when alone.
final class AdaptiveStepBudget {
  AdaptiveStepBudget({
    this.failureShrinkNumerator = adaptiveStepDefaultFailureShrinkNumerator,
    this.failureShrinkDenominator = adaptiveStepDefaultFailureShrinkDenominator,
    this.targetStepTime = adaptiveStepDefaultTargetTime,
    Stopwatch Function() stopwatch = Stopwatch.new,
  }) : _stopwatch = stopwatch,
       assert(
         failureShrinkDenominator > 0,
         'failureShrinkDenominator must be positive',
       ),
       assert(
         failureShrinkNumerator >= 0,
         'failureShrinkNumerator must not be negative',
       ),
       assert(
         failureShrinkNumerator < failureShrinkDenominator,
         'a failure must shrink the budget',
       );

  final int failureShrinkNumerator;
  final int failureShrinkDenominator;

  /// How long a step with prefill rows should take.
  final Duration targetStepTime;

  final Stopwatch Function() _stopwatch;

  int? _retrySampleCap;
  int? _retryPrefillCap;
  int? _timedPrefillCap;
  var _lastPrefillAllowance = 0;

  /// Starts timing the step about to run.
  Stopwatch startStep() => _stopwatch()..start();

  StepAdmissionBudget forStep({
    required int readySampleRows,
    required int maxBatchTokens,
  }) {
    if (maxBatchTokens <= 0) {
      return const StepAdmissionBudget(maxSampleRows: 0, maxPrefillRows: 0);
    }

    final sampleCap = _retrySampleCap;
    final uncappedSamples = _minInt(readySampleRows, maxBatchTokens);
    final maxSampleRows = sampleCap == null
        ? uncappedSamples
        : _minInt(uncappedSamples, sampleCap);
    final hardRoom = maxBatchTokens - maxSampleRows;
    if (hardRoom <= 0) {
      return StepAdmissionBudget(
        maxSampleRows: maxSampleRows,
        maxPrefillRows: 0,
      );
    }

    _lastPrefillAllowance = [
      hardRoom,
      ?_retryPrefillCap,
      if (maxSampleRows > 0) ?_timedPrefillCap,
    ].reduce(_minInt);
    return StepAdmissionBudget(
      maxSampleRows: maxSampleRows,
      maxPrefillRows: _lastPrefillAllowance,
    );
  }

  /// Learns from a step that ran with [shape] and took [elapsed].
  void observe({
    required StepBatchShape shape,
    required bool succeeded,
    int? backendCode,
    Duration? elapsed,
  }) {
    if (!shape.hasWork) return;

    if (backendCode == decodeKvSlotUnavailableBackendCode) {
      _shrinkAfterSlotFailure(shape);
      return;
    }
    if (!succeeded) return;
    _resetRetryCaps();
    if (elapsed != null) _fitToTime(shape, elapsed);
  }

  /// Scales the prefill allowance so the next full step lands near the
  /// target. Only a step that used its whole allowance, or ran past the
  /// target, says how many rows fit; growth is at most double per step.
  void _fitToTime(StepBatchShape shape, Duration elapsed) {
    if (shape.prefillRows == 0) return;
    final overran = elapsed > targetStepTime;
    if (!overran && shape.prefillRows < _lastPrefillAllowance) return;
    final rows = shape.sampleRows + shape.prefillRows;
    final fitted =
        rows *
        targetStepTime.inMicroseconds ~/
        _clampMin(elapsed.inMicroseconds, 1);
    _timedPrefillCap = _clampMin(
      _minInt(fitted, rows * 2) - shape.sampleRows,
      adaptiveStepMinimumSoloPrefillRows,
    );
  }

  void _resetRetryCaps() {
    _retrySampleCap = null;
    _retryPrefillCap = null;
  }

  void _shrinkAfterSlotFailure(StepBatchShape shape) {
    if (shape.prefillRows > 0) {
      final minimum = shape.isMixed
          ? adaptiveStepMinimumMixedPrefillRows
          : adaptiveStepMinimumSoloPrefillRows;
      _retryPrefillCap = _shrinkBelowObserved(shape.prefillRows, minimum);
      return;
    }
    if (shape.sampleRows > adaptiveStepMinimumSampleRows) {
      _retrySampleCap = _shrinkBelowObserved(
        shape.sampleRows,
        adaptiveStepMinimumSampleRows,
      );
    }
  }

  int _shrinkBelowObserved(int observedRows, int minimum) {
    final shrunken =
        observedRows * failureShrinkNumerator ~/ failureShrinkDenominator;
    return _clampMin(shrunken, minimum);
  }
}

int _clampMin(int value, int minimum) {
  if (value < minimum) return minimum;
  return value;
}

int _minInt(int left, int right) => left < right ? left : right;
