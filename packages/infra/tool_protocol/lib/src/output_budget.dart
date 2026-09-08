import 'dart:math' as math;

import 'package:tool_protocol/src/models/tool_call_response.dart';

// 4 characters per token is a conservative estimate.
const estimatedCharactersPerToken = 4;

/// Ceiling on what one tool result may put into the conversation.
const int defaultMaxToolCallCharacters = 4000;

/// Characters left out of [maxChars] for the content told under a failure's
/// [message].
int roomUnderMessage(String message, {required int maxChars}) {
  final room = maxChars - message.length - messageSeparator.length;
  return room < 0 ? 0 : room;
}

/// Characters one tool result may occupy, given [availableTokens] of free
/// context and the [maxToolCallCharacters] ceiling no result may exceed
/// however much context is free.
int maxOutputCharsFor({
  required int availableTokens,
  required int maxToolCallCharacters,
}) => math.min(
  availableTokens * estimatedCharactersPerToken,
  maxToolCallCharacters,
);
