import 'package:gguf_reader/src/gguf_header.dart';
import 'package:intentions/intentions.dart';

@model
sealed class GgufReadResult {
  const GgufReadResult();
}

@model
final class GgufRead extends GgufReadResult {
  const GgufRead(this.header);

  final GgufHeader header;
}

/// The file opened but is not a well-formed GGUF header.
@model
final class GgufMalformed extends GgufReadResult {
  const GgufMalformed(this.reason);

  final String reason;
}

/// The file could not be opened or read.
@model
final class GgufUnreadable extends GgufReadResult {
  const GgufUnreadable(this.reason);

  final String reason;
}
