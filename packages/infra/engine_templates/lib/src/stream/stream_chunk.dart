final class StreamChunk {
  const StreamChunk({
    required this.text,
    required this.tokenCountDelta,
  });

  final String text;
  final int tokenCountDelta;
}
