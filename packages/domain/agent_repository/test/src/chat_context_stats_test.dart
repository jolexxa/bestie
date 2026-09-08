import 'package:agent_repository/agent_repository.dart';
import 'package:test/test.dart';

void main() {
  group('ChatContextStats', () {
    test('remainingPercent computes correctly', () {
      const stats = ChatContextStats(
        contextSize: 4096,
        budgetTokens: 1000,
        cachedTokens: 200,
        maxOutputTokens: 512,
        safetyMarginTokens: 100,
      );

      // (1000 - 200 + 0) * 100 ~/ 1000 = 80
      expect(stats.remainingPercent, 80);
    });

    test('remainingPercent clamps to 0-100', () {
      const stats = ChatContextStats(
        contextSize: 4096,
        budgetTokens: 100,
        cachedTokens: 500,
        maxOutputTokens: 512,
        safetyMarginTokens: 100,
      );

      expect(stats.remainingPercent, 0);
    });

    test('remainingPercent accounts for pinnedPrefixTokens', () {
      const stats = ChatContextStats(
        contextSize: 4096,
        budgetTokens: 1000,
        cachedTokens: 200,
        maxOutputTokens: 512,
        safetyMarginTokens: 100,
        pinnedPrefixTokens: 500,
      );

      // conversationBudget = 1000 - 500 = 500
      // (1000 - 200 + 0) * 100 ~/ 500 = 160 → clamped to 100
      expect(stats.remainingPercent, 100);
    });

    test('remainingPercent returns 100 when conversationBudget <= 0', () {
      const stats = ChatContextStats(
        contextSize: 4096,
        budgetTokens: 100,
        cachedTokens: 50,
        maxOutputTokens: 512,
        safetyMarginTokens: 100,
        pinnedPrefixTokens: 200,
      );

      expect(stats.remainingPercent, 100);
    });

    test('remainingPercent ignores reasoningTokens', () {
      // Reasoning tokens are already part of cachedTokens (they live in
      // the KV cache during the turn), so they should not be added back
      // — that would treat real cache pressure as free.
      const stats = ChatContextStats(
        contextSize: 4096,
        budgetTokens: 1000,
        cachedTokens: 200,
        maxOutputTokens: 512,
        safetyMarginTokens: 100,
        reasoningTokens: 100,
      );

      // (1000 - 200) * 100 ~/ 1000 = 80
      expect(stats.remainingPercent, 80);
    });

    test('defaults', () {
      const stats = ChatContextStats(
        contextSize: 4096,
        budgetTokens: 1000,
        cachedTokens: 50,
        maxOutputTokens: 512,
        safetyMarginTokens: 100,
      );

      expect(stats.reasoningTokens, 0);
      expect(stats.pinnedPrefixTokens, 0);
    });
  });
}
