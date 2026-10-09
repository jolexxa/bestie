import 'dart:typed_data';

import 'package:inference/src/runtime/tokenized_string.dart';

abstract interface class Tokenizer {
  TokenizeResult tokenize(TokenizeRequest request);
}

abstract interface class Detokenizer implements Tokenizer {
  DetokenizeResult detokenize(DetokenizeRequest request);
}

final class TokenizeRequest {
  const TokenizeRequest({
    required this.text,
    this.addSpecial = true,
    this.parseSpecial = true,
  });

  final String text;
  final bool addSpecial;
  final bool parseSpecial;
}

sealed class TokenizeResult {
  const TokenizeResult();
}

final class TokenizeSucceeded extends TokenizeResult {
  const TokenizeSucceeded(this.tokens);

  final TokenizedString tokens;
}

final class TokenizeFailed extends TokenizeResult {
  const TokenizeFailed({
    required this.message,
    required this.stackTrace,
  });

  final String message;
  final String stackTrace;
}

final class DetokenizeRequest {
  const DetokenizeRequest({required this.token});

  final TokenId token;
}

sealed class DetokenizeResult {
  const DetokenizeResult();
}

final class DetokenizeSucceeded extends DetokenizeResult {
  const DetokenizeSucceeded(this.bytes);

  final Uint8List bytes;
}

final class DetokenizeFailed extends DetokenizeResult {
  const DetokenizeFailed({
    required this.message,
    required this.stackTrace,
  });

  final String message;
  final String stackTrace;
}
