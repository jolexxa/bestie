import 'package:bestie_platform_abstractions/bestie_platform_abstractions.dart';
import 'package:bestie_platform_windows/bestie_platform_windows.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:win32_dart/win32_dart.dart';

import 'mocks.dart';

void main() {
  late MockHardLinkQuery hardLink;
  late WindowsExecutableLinkDataSource dataSource;

  setUp(() {
    hardLink = MockHardLinkQuery();
    dataSource = WindowsExecutableLinkDataSource(hardLink: hardLink);
  });

  test('reports success when the hardlink is created', () {
    when(
      () => hardLink.create(
        linkPath: any(named: 'linkPath'),
        targetPath: any(named: 'targetPath'),
      ),
    ).thenReturn(const HardLinkSucceeded());

    final result = dataSource.link(
      linkPath: r'C:\bin\ls.exe',
      targetPath: r'C:\bin\coreutils.exe',
    );

    expect(result, isA<ExecutableLinkCreated>());
    verify(
      () => hardLink.create(
        linkPath: r'C:\bin\ls.exe',
        targetPath: r'C:\bin\coreutils.exe',
      ),
    ).called(1);
  });

  test('carries the Win32 failure message through', () {
    when(
      () => hardLink.create(
        linkPath: any(named: 'linkPath'),
        targetPath: any(named: 'targetPath'),
      ),
    ).thenReturn(
      const HardLinkFailed(
        Win32Failure(
          function: 'CreateHardLinkW',
          code: 183,
          message: 'Cannot create a file when it exists.',
          channel: Win32ErrorChannel.lastError,
        ),
      ),
    );

    final result = dataSource.link(
      linkPath: r'C:\bin\ls.exe',
      targetPath: r'C:\bin\coreutils.exe',
    );

    expect(result, isA<ExecutableLinkFailed>());
    expect(
      (result as ExecutableLinkFailed).reason,
      'Cannot create a file when it exists.',
    );
  });
}
