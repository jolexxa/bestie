import 'package:bestie_platform_abstractions/bestie_platform_abstractions.dart';
import 'package:test/test.dart';

/// The shape a termios-style override takes: it undoes itself and has no
/// pre-override target to write to.
class _PlainOverride extends TerminalOverride {
  const _PlainOverride();

  @override
  Future<void> revert() async {}
}

void main() {
  // Only an fd redirect saves a handle to what it displaced, so the base
  // class has to answer null rather than make every override declare one.
  test('an override has no side channel unless it captured one', () {
    const override = _PlainOverride();

    expect(override.originalSink, isNull);
    expect(override.revert(), completes);
  });
}
