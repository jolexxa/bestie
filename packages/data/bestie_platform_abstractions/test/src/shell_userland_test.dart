import 'package:bestie_platform_abstractions/bestie_platform_abstractions.dart';
import 'package:test/test.dart';

void main() {
  test('carries the resolved paths and executables as data', () {
    const userland = ShellUserland(
      binDir: r'C:\cow\shell\bin',
      shellPath: r'C:\cow\shell\bin\brush.exe',
      executables: ShellExecutables.windows,
    );

    expect(userland.binDir, r'C:\cow\shell\bin');
    expect(userland.shellPath, r'C:\cow\shell\bin\brush.exe');
    expect(userland.executables, ShellExecutables.windows);
  });
}
