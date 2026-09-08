import 'package:bestie_platform_abstractions/bestie_platform_abstractions.dart';
import 'package:test/test.dart';

void main() {
  test('names both halves of the console host', () {
    const host = ConsoleHost(
      libraryPath: r'C:\cow\lib\conpty.dll',
      executablePath: r'C:\cow\lib\OpenConsole.exe',
    );

    expect(host.libraryPath, r'C:\cow\lib\conpty.dll');
    expect(host.executablePath, r'C:\cow\lib\OpenConsole.exe');
  });
}
