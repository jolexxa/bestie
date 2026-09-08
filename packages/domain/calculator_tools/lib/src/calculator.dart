import 'package:calculator_tools/src/models/calculation_outcome.dart';
import 'package:eval_ex/expression.dart';
import 'package:intentions/intentions.dart';

/// Evaluates arithmetic.
@repository
class Calculator {
  const Calculator();

  CalculationOutcome evaluate(String expression) {
    try {
      return CalculationSucceeded(Expression(expression).eval().toString());
    } on Exception catch (error) {
      return CalculationFailed('$error');
    }
  }
}
