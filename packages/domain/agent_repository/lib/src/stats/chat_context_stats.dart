import 'package:intentions/intentions.dart';

@model
final class ChatContextStats {
  const ChatContextStats({
    required this.contextSize,
    required this.budgetTokens,
    required this.cachedTokens,
    required this.maxOutputTokens,
    required this.safetyMarginTokens,
    this.reasoningTokens = 0,
    this.pinnedPrefixTokens = 0,
  });

  final int contextSize;
  final int budgetTokens;
  final int cachedTokens;
  final int maxOutputTokens;
  final int safetyMarginTokens;
  final int reasoningTokens;
  final int pinnedPrefixTokens;

  int get remainingPercent {
    final conversationBudget = budgetTokens - pinnedPrefixTokens;
    if (conversationBudget <= 0) return 100;
    return ((budgetTokens - cachedTokens) * 100 ~/ conversationBudget).clamp(
      0,
      100,
    );
  }
}
