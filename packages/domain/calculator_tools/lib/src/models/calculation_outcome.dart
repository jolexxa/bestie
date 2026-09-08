import 'package:intentions/intentions.dart';

@model
sealed class CalculationOutcome {
  const CalculationOutcome();
}

@model
final class CalculationSucceeded extends CalculationOutcome {
  const CalculationSucceeded(this.value);

  /// The result, at the precision the evaluator worked to.
  final String value;
}

@model
final class CalculationFailed extends CalculationOutcome {
  const CalculationFailed(this.reason);

  final String reason;
}
