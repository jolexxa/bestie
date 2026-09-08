import 'package:calculator_tools/calculator_tools.dart';
import 'package:test/test.dart';

void main() {
  const calculator = Calculator();

  test('evaluates arithmetic', () {
    final outcome = calculator.evaluate('2 ^ 10');

    expect((outcome as CalculationSucceeded).value, '1024');
  });

  test('evaluates the functions it advertises', () {
    expect(
      (calculator.evaluate('SQRT(144)') as CalculationSucceeded).value,
      '12',
    );
    expect(
      (calculator.evaluate('IF(3 > 2, 1, 0)') as CalculationSucceeded).value,
      '1',
    );
  });

  test('carries the reason it could not evaluate', () {
    final outcome = calculator.evaluate('2 +');

    expect(outcome, isA<CalculationFailed>());
    expect((outcome as CalculationFailed).reason, isNotEmpty);
  });
}
