import 'package:bestie_shell_use_case/bestie_shell_use_case.dart';
import 'package:test/test.dart';

void main() {
  test('the scrollback key defaults to the shipped size', () {
    final key = ShellConfigKeys.defaults().scrollbackMb;

    expect(key.id, 'app.shell_scrollback_mb');
    expect(key.defaultValue(), defaultShellScrollbackMb);
    expect(key.field.label, 'Shell Scrollback');
  });
}
