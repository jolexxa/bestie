import 'package:bestie_platform_abstractions/bestie_platform_abstractions.dart';
import 'package:test/test.dart';

void main() {
  test('a POSIX location names the spawner helper', () {
    const location = PosixProcessHostLocation(spawnerBinaryPath: '/spawner');

    expect(location, isA<ProcessHostLocation>());
    expect(location.spawnerBinaryPath, '/spawner');
  });

  test('a Windows location names the ConPTY library', () {
    const location = WindowsProcessHostLocation(
      conptyLibraryPath: r'C:\conpty.dll',
    );

    expect(location, isA<ProcessHostLocation>());
    expect(location.conptyLibraryPath, r'C:\conpty.dll');
  });
}
