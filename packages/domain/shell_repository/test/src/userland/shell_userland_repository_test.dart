import 'dart:convert';

import 'package:bestie_platform_abstractions/bestie_platform_abstractions.dart';
import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:mocktail/mocktail.dart';
import 'package:process_host/process_host.dart';
import 'package:shell_repository/shell_repository.dart';
import 'package:test/test.dart';

class _MockLinkDataSource extends Mock implements ExecutableLinkDataSource {}

class _MockProcessRunner extends Mock implements ProcessRunner {}

ProcessCaptureResult _listed(int code, String out) => ProcessCaptureCompleted(
  exit: ProcessExited(code),
  stdout: utf8.encode(out),
  stderr: const [],
);

void main() {
  setUpAll(() {
    registerFallbackValue(<String>[]);
    registerFallbackValue(<int>[]);
  });

  late _MockLinkDataSource link;
  late _MockProcessRunner processRunner;

  setUp(() {
    link = _MockLinkDataSource();
    processRunner = _MockProcessRunner();
    when(
      () => link.link(
        linkPath: any(named: 'linkPath'),
        targetPath: any(named: 'targetPath'),
      ),
    ).thenReturn(const ExecutableLinkCreated());
  });

  void whenListReturns(ProcessCaptureResult result) {
    when(
      () => processRunner.runCaptured(
        any(),
        arguments: any(named: 'arguments'),
        stdin: any(named: 'stdin'),
      ),
    ).thenAnswer((_) async => result);
  }

  FileSystem windowsFs() => MemoryFileSystem(style: FileSystemStyle.windows);
  FileSystem posixFs() => MemoryFileSystem();

  ShellUserland shell(String binDir, {required bool windows}) => ShellUserland(
    binDir: binDir,
    shellPath: windows ? '$binDir\\brush.exe' : '$binDir/brush',
    executables: windows ? ShellExecutables.windows : ShellExecutables.posix,
  );

  ShellUserlandRepository repository(FileSystem fs) => ShellUserlandRepository(
    linkDataSource: link,
    fileSystem: fs,
    processRunner: processRunner,
  );

  test('links each listed utility to the multicall', () async {
    final fs = posixFs();
    fs.file('/opt/bin/coreutils').createSync(recursive: true);
    whenListReturns(_listed(0, 'ls cat coreutils'));

    final result = await repository(
      fs,
    ).ensureProvisioned(shell('/opt/bin', windows: false));

    expect(result, isA<ProvisionSucceeded>());
    expect((result as ProvisionSucceeded).linkedNames, ['ls', 'cat']);
    verify(
      () =>
          link.link(linkPath: '/opt/bin/ls', targetPath: '/opt/bin/coreutils'),
    ).called(1);
    verify(
      () =>
          link.link(linkPath: '/opt/bin/cat', targetPath: '/opt/bin/coreutils'),
    ).called(1);
  });

  test('exposes the linked utilities once provisioned', () async {
    final fs = posixFs();
    fs.file('/opt/bin/coreutils').createSync(recursive: true);
    whenListReturns(_listed(0, 'ls cat'));
    final subject = repository(fs);

    expect(subject.availableUtilities, isEmpty);
    await subject.ensureProvisioned(shell('/opt/bin', windows: false));

    expect(subject.availableUtilities, ['ls', 'cat']);
  });

  test('applies the Windows executable extension to link names', () async {
    final fs = windowsFs();
    fs.file(r'C:\bin\coreutils.exe').createSync(recursive: true);
    whenListReturns(_listed(0, 'ls'));

    await repository(fs).ensureProvisioned(shell(r'C:\bin', windows: true));

    verify(
      () => link.link(
        linkPath: r'C:\bin\ls.exe',
        targetPath: r'C:\bin\coreutils.exe',
      ),
    ).called(1);
  });

  test('skips the work when the marker matches the multicall', () async {
    final fs = posixFs();
    fs.file('/opt/bin/coreutils').createSync(recursive: true);
    whenListReturns(_listed(0, 'ls'));
    final subject = repository(fs);
    final userland = shell('/opt/bin', windows: false);

    final first = await subject.ensureProvisioned(userland);
    final second = await subject.ensureProvisioned(userland);

    expect(first, isA<ProvisionSucceeded>());
    expect(second, isA<ProvisionUpToDate>());
    // The multicall was interrogated once, not on the cached second launch.
    verify(
      () => processRunner.runCaptured(
        any(),
        arguments: any(named: 'arguments'),
        stdin: any(named: 'stdin'),
      ),
    ).called(1);
  });

  test('reports the utilities from the marker on a cached launch', () async {
    final fs = posixFs();
    fs.file('/opt/bin/coreutils').createSync(recursive: true);
    whenListReturns(_listed(0, 'ls cat'));
    final userland = shell('/opt/bin', windows: false);
    await repository(fs).ensureProvisioned(userland);

    // A fresh launch over the same userland: nothing to relink, but the list
    // still has to be answerable.
    final relaunched = repository(fs);
    final result = await relaunched.ensureProvisioned(userland);

    expect(result, isA<ProvisionUpToDate>());
    expect(relaunched.availableUtilities, ['ls', 'cat']);
  });

  test('relinks when the marker is stale', () async {
    final fs = posixFs();
    fs.file('/opt/bin/coreutils').createSync(recursive: true);
    fs.file('/opt/bin/.coreutils-linked').writeAsStringSync('an-old-stamp\nls');
    whenListReturns(_listed(0, 'ls'));

    final result = await repository(
      fs,
    ).ensureProvisioned(shell('/opt/bin', windows: false));

    expect(result, isA<ProvisionSucceeded>());
    verify(
      () =>
          link.link(linkPath: '/opt/bin/ls', targetPath: '/opt/bin/coreutils'),
    ).called(1);
  });

  test('relinks when the marker predates the utility list', () async {
    final fs = posixFs();
    fs.file('/opt/bin/coreutils').createSync(recursive: true);
    whenListReturns(_listed(0, 'ls cat'));
    final userland = shell('/opt/bin', windows: false);
    await repository(fs).ensureProvisioned(userland);

    // Truncate to the old single-line format: the stamp still matches, but the
    // utility names are unrecoverable, so it must reprovision rather than
    // report an empty userland.
    final marker = fs.file('/opt/bin/.coreutils-linked');
    marker.writeAsStringSync(marker.readAsStringSync().split('\n').first);

    final relaunched = repository(fs);
    final result = await relaunched.ensureProvisioned(userland);

    expect(result, isA<ProvisionSucceeded>());
    expect(relaunched.availableUtilities, ['ls', 'cat']);
  });

  test('replaces a stale symlink before relinking', () async {
    final fs = posixFs();
    fs.file('/opt/bin/coreutils').createSync(recursive: true);
    fs.link('/opt/bin/ls').createSync('/somewhere/else');
    whenListReturns(_listed(0, 'ls'));

    final result = await repository(
      fs,
    ).ensureProvisioned(shell('/opt/bin', windows: false));

    expect(result, isA<ProvisionSucceeded>());
    verify(
      () =>
          link.link(linkPath: '/opt/bin/ls', targetPath: '/opt/bin/coreutils'),
    ).called(1);
  });

  test('replaces a stale regular file before relinking', () async {
    final fs = windowsFs();
    fs.file(r'C:\bin\coreutils.exe').createSync(recursive: true);
    fs.file(r'C:\bin\ls.exe').createSync();
    whenListReturns(_listed(0, 'ls'));

    await repository(fs).ensureProvisioned(shell(r'C:\bin', windows: true));

    verify(
      () => link.link(
        linkPath: r'C:\bin\ls.exe',
        targetPath: r'C:\bin\coreutils.exe',
      ),
    ).called(1);
  });

  test('fails when the multicall is missing', () async {
    final result = await repository(
      posixFs(),
    ).ensureProvisioned(shell('/opt/bin', windows: false));

    expect(result, isA<ProvisionFailed>());
    expect((result as ProvisionFailed).reason, contains('not found'));
    verifyNever(
      () => link.link(
        linkPath: any(named: 'linkPath'),
        targetPath: any(named: 'targetPath'),
      ),
    );
  });

  test('fails when coreutils cannot be started', () async {
    final fs = posixFs();
    fs.file('/opt/bin/coreutils').createSync(recursive: true);
    whenListReturns(
      const ProcessCaptureNotStarted(
        SpawnFailure(function: 'posix_spawnp', message: 'boom', code: 2),
      ),
    );

    final result = await repository(
      fs,
    ).ensureProvisioned(shell('/opt/bin', windows: false));

    expect(result, isA<ProvisionFailed>());
    expect((result as ProvisionFailed).reason, contains('boom'));
  });

  test('fails when --list exits non-zero', () async {
    final fs = posixFs();
    fs.file('/opt/bin/coreutils').createSync(recursive: true);
    whenListReturns(_listed(1, ''));

    final result = await repository(
      fs,
    ).ensureProvisioned(shell('/opt/bin', windows: false));

    expect(result, isA<ProvisionFailed>());
    expect((result as ProvisionFailed).reason, contains('--list'));
  });

  test('stops and reports the first link that fails', () async {
    final fs = posixFs();
    fs.file('/opt/bin/coreutils').createSync(recursive: true);
    whenListReturns(_listed(0, 'ls cat'));
    when(
      () => link.link(
        linkPath: '/opt/bin/cat',
        targetPath: any(named: 'targetPath'),
      ),
    ).thenReturn(const ExecutableLinkFailed('disk full'));

    final result = await repository(
      fs,
    ).ensureProvisioned(shell('/opt/bin', windows: false));

    expect(result, isA<ProvisionFailed>());
    expect((result as ProvisionFailed).reason, contains('cat'));
    expect(result.reason, contains('disk full'));
  });

  test('leaves no marker behind when provisioning fails', () async {
    final fs = posixFs();
    fs.file('/opt/bin/coreutils').createSync(recursive: true);
    whenListReturns(_listed(1, ''));

    final subject = repository(fs);
    await subject.ensureProvisioned(shell('/opt/bin', windows: false));

    expect(fs.file('/opt/bin/.coreutils-linked').existsSync(), isFalse);
    expect(subject.availableUtilities, isEmpty);
  });
}
