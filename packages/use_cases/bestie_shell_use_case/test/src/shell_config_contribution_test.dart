import 'package:bestie_shell_use_case/bestie_shell_use_case.dart';
import 'package:test/test.dart';

void main() {
  final contribution = ShellConfigContribution();

  test('the scrollback key defaults to the shipped size', () {
    final key = contribution.configKeys.scrollbackMb;

    expect(key.id, 'app.shell_scrollback_mb');
    expect(key.defaultValue(), defaultShellScrollbackMb);
  });

  test('offers nothing in the overlay', () {
    expect(contribution.entries, isEmpty);
  });
}
