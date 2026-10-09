import 'package:completion_runtime/completion_runtime.dart';
import 'package:test/test.dart';

void main() {
  test('a failed close carries why', () {
    expect(
      const AgentCloseFailed(message: 'gone').message,
      'gone',
    );
  });

  test('the primary claims nothing; a subagent claims its share', () {
    const primary = PrimaryPoolLease(id: 'primary:1', usedTokens: 9);
    const subagent = SubagentPoolLease(
      id: 'sub:a',
      usedTokens: 3,
      claimedTokens: 512,
    );

    expect(primary.claimedTokens, 0);
    expect(subagent.claimedTokens, 512);
  });
}
