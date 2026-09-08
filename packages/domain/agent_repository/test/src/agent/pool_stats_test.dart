import 'package:agent_repository/agent_repository.dart';
import 'package:test/test.dart';

void main() {
  test('computes remaining context relative to the unpinned budget', () {
    const stats = ChatContextStats(
      contextSize: 1000,
      budgetTokens: 800,
      cachedTokens: 500,
      maxOutputTokens: 100,
      safetyMarginTokens: 20,
      pinnedPrefixTokens: 200,
    );

    expect(stats.remainingPercent, 50);
  });

  test('clamps an exhausted or non-positive conversation budget', () {
    const exhausted = ChatContextStats(
      contextSize: 100,
      budgetTokens: 80,
      cachedTokens: 120,
      maxOutputTokens: 0,
      safetyMarginTokens: 0,
    );
    const empty = ChatContextStats(
      contextSize: 100,
      budgetTokens: 80,
      cachedTokens: 0,
      maxOutputTokens: 0,
      safetyMarginTokens: 0,
      pinnedPrefixTokens: 80,
    );

    expect(exhausted.remainingPercent, 0);
    expect(empty.remainingPercent, 100);
  });
}
