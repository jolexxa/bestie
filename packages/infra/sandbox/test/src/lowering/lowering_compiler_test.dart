import 'package:sandbox/src/lowering/lowered_policy.dart';
import 'package:sandbox/src/lowering/lowering_compiler.dart';
import 'package:sandbox/src/lowering/lowering_outcome.dart';
import 'package:sandbox/src/lowering/native_deny_lowering.dart';
import 'package:sandbox/src/sandbox_spec.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  group('LoweringCompiler', () {
    test('resolves then lowers to a masked program', () {
      final compiler = LoweringCompiler(const NativeDenyLowering(), memFs());
      final outcome = compiler.compile(
        const SandboxSpec(workspaceRoot: '/w', readableRoots: ['/usr']),
      );
      expect(outcome, isA<LoweringSucceeded>());
      final policy = (outcome as LoweringSucceeded).policy;
      expect(policy, isA<MaskedProgram>());
      expect(
        (policy as MaskedProgram).grants,
        contains(const Grant('/w', GrantAccess.readWrite)),
      );
    });

    test('keeps a deny on a missing path rather than failing', () {
      final compiler = LoweringCompiler(const NativeDenyLowering(), memFs());
      final outcome = compiler.compile(
        const SandboxSpec(workspaceRoot: '/w', deniedReads: ['/home/.aws']),
      );
      expect(outcome, isA<LoweringSucceeded>());
      expect(
        (outcome as LoweringSucceeded).report.deniedReads,
        ['/home/.aws'],
      );
    });
  });
}
