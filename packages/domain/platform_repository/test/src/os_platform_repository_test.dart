import 'package:bestie_platform_abstractions/bestie_platform_abstractions.dart';
import 'package:mocktail/mocktail.dart';
import 'package:platform_repository/platform_repository.dart';
import 'package:test/test.dart';

class _MockSystemInfoDataSource extends Mock implements SystemInfoDataSource {}

class _MockClipboardDataSource extends Mock implements ClipboardDataSource {}

class _MockDiskSpaceDataSource extends Mock implements DiskSpaceDataSource {}

class _MockTerminalEnvironmentDataSource extends Mock
    implements TerminalEnvironmentDataSource {}

class _MockTerminalOverride extends Mock implements TerminalOverride {}

const _platform = LinuxPlatform(
  architecture: OSArchitecture.linuxX64,
  homeDir: '/home/cow',
  tempDir: '/tmp',
  bestieDir: '/home/cow/.bestie',
  configFile: '/home/cow/.bestie/bestie.json',
  conversationsDir: '/home/cow/.bestie/conversations',
  curlLibraryPath: '/opt/libcurl.so',
  caCertPath: '/opt/cacert.pem',
  creditsPath: '/opt/CREDITS.md',
);

const _snapshot = SystemInfoSnapshot(
  logicalCoreCount: 8,
  totalRamBytes: 16000,
  availableRamBytes: 4000,
  platformAlwaysUnified: false,
);

void main() {
  late _MockSystemInfoDataSource systemInfo;
  late _MockClipboardDataSource clipboard;
  late _MockDiskSpaceDataSource diskSpace;
  late _MockTerminalEnvironmentDataSource terminalEnvironment;
  late OSPlatformRepository repository;

  setUp(() {
    systemInfo = _MockSystemInfoDataSource();
    clipboard = _MockClipboardDataSource();
    diskSpace = _MockDiskSpaceDataSource();
    terminalEnvironment = _MockTerminalEnvironmentDataSource();
    repository = OSPlatformRepository(
      platform: _platform,
      systemInfoDataSource: systemInfo,
      clipboardDataSource: clipboard,
      diskSpaceDataSource: diskSpace,
      terminalEnvironmentDataSource: terminalEnvironment,
    );
  });

  test('the platform configuration is available without a data source', () {
    expect(repository.platform, same(_platform));
  });

  test('a system-information read is answered by the data source', () {
    when(systemInfo.readSystemInfo).thenReturn(_snapshot);

    expect(repository.readSystemInfo(), same(_snapshot));
    verify(systemInfo.readSystemInfo).called(1);
  });

  test('a copy reaches the clipboard data source', () async {
    when(() => clipboard.copy(any())).thenAnswer((_) async {});

    await repository.copyToClipboard('cow');

    verify(() => clipboard.copy('cow')).called(1);
  });

  test('free space is reported for the path asked about', () {
    when(() => diskSpace.availableBytes(any())).thenReturn(4096);

    expect(repository.availableDiskSpaceBytes('/models'), 4096);
    verify(() => diskSpace.availableBytes('/models')).called(1);
  });

  group('terminal overrides', () {
    late _MockTerminalOverride override;

    setUp(() => override = _MockTerminalOverride());

    test('a stderr redirect hands back the override that undoes it', () {
      when(
        () => terminalEnvironment.redirectStderr(
          targetPath: any(named: 'targetPath'),
        ),
      ).thenReturn(override);

      expect(
        repository.redirectStderr(targetPath: '/home/cow/.bestie/native.log'),
        same(override),
      );
      verify(
        () => terminalEnvironment.redirectStderr(
          targetPath: '/home/cow/.bestie/native.log',
        ),
      ).called(1);
    });

    test('an input capture passes the groups through untouched', () {
      when(() => terminalEnvironment.captureInput(any())).thenReturn(override);

      expect(
        repository.captureInput(const {
          InputCapture.controlKeys,
          InputCapture.flowControl,
        }),
        same(override),
      );
      verify(
        () => terminalEnvironment.captureInput(const {
          InputCapture.controlKeys,
          InputCapture.flowControl,
        }),
      ).called(1);
    });

    test('a window title change hands back its override', () {
      when(
        () => terminalEnvironment.setWindowTitle(any()),
      ).thenReturn(override);

      expect(repository.setWindowTitle('cow'), same(override));
      verify(() => terminalEnvironment.setWindowTitle('cow')).called(1);
    });

    // Every override is optional: a platform that cannot honour one says so
    // by returning null, and the repository must not invent a handle.
    test('a platform that cannot honour one reports null through', () {
      when(
        () => terminalEnvironment.redirectStderr(
          targetPath: any(named: 'targetPath'),
        ),
      ).thenReturn(null);
      when(() => terminalEnvironment.captureInput(any())).thenReturn(null);
      when(() => terminalEnvironment.setWindowTitle(any())).thenReturn(null);

      expect(repository.redirectStderr(targetPath: '/dev/null'), isNull);
      expect(repository.captureInput(const {InputCapture.editingKeys}), isNull);
      expect(repository.setWindowTitle('cow'), isNull);
    });
  });
}
