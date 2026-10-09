import 'package:inference/src/models/tokenizer.dart';

abstract interface class Model {
  Tokenizer get tokenizer;

  Future<DisposeModelResult> dispose();
}

sealed class DisposeModelResult {
  const DisposeModelResult();
}

final class ModelDisposed extends DisposeModelResult {
  const ModelDisposed();
}

final class DisposeModelFailed extends DisposeModelResult {
  const DisposeModelFailed({
    required this.message,
    required this.stackTrace,
  });

  final String message;
  final String stackTrace;
}
