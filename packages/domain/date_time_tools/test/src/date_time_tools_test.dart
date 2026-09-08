import 'package:clock/clock.dart';
import 'package:date_time_tools/date_time_tools.dart';
import 'package:test/test.dart';

void main() {
  test('reads the ambient clock rather than the system one', () {
    final fixed = DateTime(2026, 8, 9, 14, 30);

    expect(
      withClock(Clock.fixed(fixed), () => const DateTimeTools().now()),
      fixed,
    );
  });
}
