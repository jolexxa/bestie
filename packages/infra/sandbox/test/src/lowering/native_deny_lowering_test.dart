import 'package:sandbox/src/lowering/glob.dart';
import 'package:sandbox/src/lowering/lowered_policy.dart';
import 'package:sandbox/src/lowering/lowering_outcome.dart';
import 'package:sandbox/src/lowering/native_deny_lowering.dart';
import 'package:sandbox/src/lowering/resolved_spec.dart';
import 'package:sandbox/src/sandbox_spec.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  group('NativeDenyLowering', () {
    const lowering = NativeDenyLowering();

    LoweringSucceeded lower(ResolvedSpec spec, {GlobExpander? globs}) =>
        lowering.lower(spec, globs ?? GlobExpander(memFs()))
            as LoweringSucceeded;

    test('grants writable as rw and readable as read-only', () {
      final result = lower(
        const ResolvedSpec(
          readableRoots: ['/usr'],
          writableRoots: ['/w'],
          denies: [],
          network: NetworkTier.all,
        ),
      );
      final policy = result.policy as MaskedProgram;
      expect(policy.grants, [
        const Grant('/w', GrantAccess.readWrite),
        const Grant('/usr', GrantAccess.read),
      ]);
    });

    test('a path both readable and writable grants once, as rw', () {
      final result = lower(
        const ResolvedSpec(
          readableRoots: ['/w'],
          writableRoots: ['/w'],
          denies: [],
          network: NetworkTier.all,
        ),
      );
      final policy = result.policy as MaskedProgram;
      expect(policy.grants, [const Grant('/w', GrantAccess.readWrite)]);
    });

    test('passes denies through to the masked program', () {
      final result = lower(
        const ResolvedSpec(
          readableRoots: [],
          writableRoots: ['/w'],
          denies: [
            ResolvedDeny(base: '/home/.ssh', tail: '', isGlob: false),
          ],
          network: NetworkTier.all,
        ),
      );
      final policy = result.policy as MaskedProgram;
      expect(policy.denies, [const Deny('/home/.ssh')]);
    });

    test('reports plain denies as themselves', () {
      final result = lower(
        const ResolvedSpec(
          readableRoots: ['/home'],
          writableRoots: ['/w'],
          denies: [
            ResolvedDeny(base: '/home/.ssh', tail: '', isGlob: false),
          ],
          network: NetworkTier.all,
        ),
      );
      expect(result.report.readableRoots, ['/home']);
      expect(result.report.writableRoots, ['/w']);
      expect(result.report.deniedReads, ['/home/.ssh']);
    });

    test('enumerates glob denies into both the program and the report', () {
      final globs = GlobExpander(
        memFs(
          dirs: {
            '/home': ['/home/a.env', '/home/b.txt'],
          },
        ),
      );
      final result = lower(
        const ResolvedSpec(
          readableRoots: ['/home'],
          writableRoots: ['/w'],
          denies: [
            ResolvedDeny(base: '/home', tail: '*.env', isGlob: true),
          ],
          network: NetworkTier.all,
        ),
        globs: globs,
      );
      final policy = result.policy as MaskedProgram;
      expect(policy.denies, [const Deny('/home/a.env')]);
      expect(result.report.deniedReads, ['/home/a.env']);
    });
  });
}
