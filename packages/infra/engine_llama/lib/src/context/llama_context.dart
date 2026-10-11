import 'package:engine_llama/src/context/llama_context_engine.dart';
import 'package:engine_llama/src/context/llama_sequences.dart';
import 'package:engine_protocol/engine_protocol.dart';

final class LlamaContext implements Context {
  LlamaContext({
    required LlamaContextEngine engine,
    required this.envelope,
  }) : _engine = engine,
       sequences = LlamaSequences(
         engine: engine,
       );

  final LlamaContextEngine _engine;
  var _disposed = false;

  @override
  final ContextEnvelope envelope;

  @override
  int get contextSize => envelope.contextSize;

  @override
  final LlamaSequences sequences;

  @override
  Future<DisposeContextResult> dispose() async {
    if (_disposed) {
      return const DisposeContextSucceeded();
    }

    _disposed = true;
    _engine.dispose();
    return const DisposeContextSucceeded();
  }
}
