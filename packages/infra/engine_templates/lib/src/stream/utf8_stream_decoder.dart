import 'dart:convert';

/// Stateful UTF-8 decoder for token-by-token model output.
///
/// Buffers incomplete multi-byte sequences across [add] calls so a codepoint
/// split across token boundaries (e.g. an emoji) decodes correctly instead of
/// producing replacement characters. One instance per decode stream.
final class Utf8StreamDecoder {
  Utf8StreamDecoder() {
    _sink = const Utf8Decoder(allowMalformed: true).startChunkedConversion(
      StringConversionSink.fromStringSink(_decoded),
    );
  }

  final _decoded = StringBuffer();
  late final Sink<List<int>> _sink;

  /// Feeds raw bytes and returns any text that completed. Incomplete trailing
  /// bytes are held for the next call.
  String add(List<int> bytes) {
    _sink.add(bytes);
    return _drain();
  }

  /// Closes the decoder and returns any buffered trailing text. Call once at
  /// end of stream; malformed leftovers surface as replacement characters.
  String flush() {
    _sink.close();
    return _drain();
  }

  String _drain() {
    final piece = _decoded.toString();
    _decoded.clear();
    return piece;
  }
}
