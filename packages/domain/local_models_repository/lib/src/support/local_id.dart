/// Stable local model ids: a readable slug plus a content fingerprint. Two
/// quants of one model never share an id; two copies of one file do,
/// wherever each sits.
library;

import 'dart:convert';

import 'package:crypto/crypto.dart';

final _unsafe = RegExp('[^a-z0-9._]+');
final _untrimmed = RegExp(r'^[-._]+|[-._]+$');

/// Lowercase, with runs of anything but letters, digits, `.` and `_` turned
/// into one `-`.
String slugOf(String text) =>
    text.toLowerCase().replaceAll(_unsafe, '-').replaceAll(_untrimmed, '');

/// Eight hex digits of a sha256 over [sizeBytes] and [identity], which is a
/// GGUF's header bytes, or its path when the header cannot be read.
String fingerprintOf({required int sizeBytes, required List<int> identity}) {
  late Digest digest;
  sha256.startChunkedConversion(
      ChunkedConversionSink<Digest>.withCallback(
        (digests) => digest = digests.single,
      ),
    )
    ..add(utf8.encode('$sizeBytes:'))
    ..add(identity)
    ..close();
  return '$digest'.substring(0, 8);
}

/// `qwen3-1.7b-q4_k_m-1a2b3c4d`: the slug of [name], the quant when the name
/// does not already carry it, and the [fingerprint].
String localIdOf({
  required String name,
  required String fingerprint,
  String? quantLabel,
}) {
  final slug = slugOf(name);
  final quant = slugOf(quantLabel ?? '');
  return [
    slug,
    if (!slug.contains(quant)) quant,
    fingerprint,
  ].where((part) => part.isNotEmpty).join('-');
}
