import 'package:clock/clock.dart';
import 'package:intentions/intentions.dart';

/// Reads the wall clock.
@repository
class DateTimeTools {
  const DateTimeTools();

  DateTime now() => clock.now();
}
