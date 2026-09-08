import 'package:mocktail/mocktail.dart';
import 'package:sandbox_windows/sandbox_windows.dart';
import 'package:sandbox_windows/src/windows_provisioner.dart';
import 'package:test/test.dart';
import 'package:win32_dart/win32_dart.dart' show NO_INHERITANCE;

class _MockProvisioner extends Mock implements WindowsProvisioner {}

const _cap = 'S-1-15-3-1024-cow';

void main() {
  late _MockProvisioner provisioner;
  late StringBuffer stderr;

  setUp(() {
    provisioner = _MockProvisioner();
    stderr = StringBuffer();
    when(
      () => provisioner.grantCapability(
        capabilitySid: any(named: 'capabilitySid'),
        path: any(named: 'path'),
        inheritance: any(named: 'inheritance'),
      ),
    ).thenReturn(null);
  });

  SandboxAncestorGrant helper({String? capabilitySid = _cap}) =>
      SandboxAncestorGrant(
        provisioner: provisioner,
        capabilitySid: capabilitySid,
        stderr: stderr,
      );

  test('grants each path to the capability, this folder only', () {
    final code = helper().run([r'C:\', r'C:\Users']);

    expect(code, SandboxAncestorGrant.applied);
    for (final path in [r'C:\', r'C:\Users']) {
      verify(
        () => provisioner.grantCapability(
          capabilitySid: _cap,
          path: path,
          inheritance: NO_INHERITANCE,
        ),
      ).called(1);
    }
    expect(stderr.isEmpty, isTrue);
  });

  test('stops at the first grant that fails and says which', () {
    when(
      () => provisioner.grantCapability(
        capabilitySid: any(named: 'capabilitySid'),
        path: r'C:\',
        inheritance: any(named: 'inheritance'),
      ),
    ).thenReturn('access denied');

    final code = helper().run([r'C:\', r'C:\Users']);

    expect(code, SandboxAncestorGrant.failed);
    expect(stderr.toString(), contains(r'C:\: access denied'));
    verifyNever(
      () => provisioner.grantCapability(
        capabilitySid: any(named: 'capabilitySid'),
        path: r'C:\Users',
        inheritance: any(named: 'inheritance'),
      ),
    );
  });

  test('fails without granting when the capability cannot be derived', () {
    final code = helper(capabilitySid: null).run([r'C:\']);

    expect(code, SandboxAncestorGrant.failed);
    expect(stderr.toString(), contains('capability'));
    verifyNever(
      () => provisioner.grantCapability(
        capabilitySid: any(named: 'capabilitySid'),
        path: any(named: 'path'),
        inheritance: any(named: 'inheritance'),
      ),
    );
  });
}
