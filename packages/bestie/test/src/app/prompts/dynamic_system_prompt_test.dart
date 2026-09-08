import 'package:bestie/src/app/prompts/dynamic_system_prompt.dart';
import 'package:test/test.dart';

void main() {
  final now = DateTime.utc(2026, 9, 7);

  test('stamps the date and the working directory', () {
    expect(
      buildDynamicSystemPrompt(now: now, cwd: r'C:\work'),
      'It is September 7, 2026. You are currently running the following '
      r'directory: C:\work.',
    );
  });

  test('appends the platform note when there is one', () {
    expect(
      buildDynamicSystemPrompt(
        now: now,
        cwd: '/work',
        platformNote: windowsSandboxNote,
      ),
      endsWith('/work. $windowsSandboxNote'),
    );
  });
}
