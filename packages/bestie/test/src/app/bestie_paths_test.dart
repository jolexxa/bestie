import 'package:bestie_platform_abstractions/bestie_platform_abstractions.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('uses resolved home directory for paths', () {
    const homeDir = '/tmp/cow-home';
    final bestieDir = bestieDirFor(homeDir, p.posix);

    expect(resolveHomeDir(const {'HOME': homeDir}), homeDir);
    expect(bestieDir, '/tmp/cow-home/.bestie');
    expect(
      configFileFor(bestieDir, p.posix),
      '/tmp/cow-home/.bestie/bestie.json',
    );
  });

  test('resolves home directory from HOME', () {
    expect(resolveHomeDir(const {'HOME': '/home/tester'}), '/home/tester');
  });

  test('falls back to USERPROFILE when HOME is missing', () {
    expect(
      resolveHomeDir(const {'USERPROFILE': r'C:\Users\cow'}),
      r'C:\Users\cow',
    );
  });

  test('throws when no home directory can be resolved', () {
    expect(() => resolveHomeDir(const {}), throwsA(isA<StateError>()));
  });
}
