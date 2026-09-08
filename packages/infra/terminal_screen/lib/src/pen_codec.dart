/// The pen behind a line, as bytes kept beside its text: a run is `varint
/// byteLen | u8 flags | fg? | bg? | attrs?`, where a default colour carries no
/// payload, an indexed one a byte and a truecolor one three — so the common
/// run costs two bytes and a wholly plain line costs no pen at all.
///
/// ```text
/// bits 0-1  foreground kind, as ColorKind's own ordinals
/// bits 2-3  background kind
/// bit  4    attributes follow, as a varint
/// bits 5-7  reserved, zero
/// ```
library;

import 'dart:typed_data';

import 'package:byte_codec/byte_codec.dart';
import 'package:terminal_screen/src/attrs.dart';
import 'package:terminal_screen/src/packed_cell.dart';
import 'package:terminal_screen/src/sgr_encode.dart';

/// Where each field sits in a run's flags byte.
const int _fgKindShift = 0;
const int _bgKindShift = 2;
const int _kindMask = 0x3;
const int _attrsPresent = 1 << 4;

/// Where [packColor] keeps a colour's kind.
const int _colorKindShift = 24;

/// Writes one run covering [byteLen] bytes of the line's text.
void writePenRun(
  ByteWriter pen, {
  required int byteLen,
  required int fg,
  required int bg,
  required int attrs,
}) {
  final fgKind = colorKind(fg).index;
  final bgKind = colorKind(bg).index;
  pen
    ..varint(byteLen)
    ..byte(
      (fgKind << _fgKindShift) |
          (bgKind << _bgKindShift) |
          (attrs == CellAttrs.none ? 0 : _attrsPresent),
    );
  _writeColor(pen, fg, fgKind);
  _writeColor(pen, bg, bgKind);
  if (attrs != CellAttrs.none) pen.varint(attrs);
}

void _writeColor(ByteWriter pen, int packed, int kind) {
  switch (ColorKind.values[kind]) {
    case ColorKind.defaultForeground:
    case ColorKind.defaultBackground:
      return;
    case ColorKind.indexed:
      pen.byte(colorIndex(packed));
    case ColorKind.rgb:
      pen
        ..byte(colorRed(packed))
        ..byte(colorGreen(packed))
        ..byte(colorBlue(packed));
  }
}

/// Reads a colour back out in the form [packColor] produces, which is a shift
/// and a mask because the kinds are `ColorKind`'s own ordinals.
int _readColor(ByteReader pen, int kind) => switch (ColorKind.values[kind]) {
  ColorKind.defaultForeground => packedDefaultFg,
  ColorKind.defaultBackground => packedDefaultBg,
  ColorKind.indexed => (kind << _colorKindShift) | pen.byte(),
  ColorKind.rgb =>
    (kind << _colorKindShift) |
        (pen.byte() << 16) |
        (pen.byte() << 8) |
        pen.byte(),
};

/// Calls [onRun] for each run [pen] holds, in order — an empty [pen] yielding
/// nothing, which is how a wholly plain line is stored.
void readPen(
  Uint8List pen,
  void Function(int byteLen, int fg, int bg, int attrs) onRun,
) {
  final reader = ByteReader(pen);
  while (reader.isNotEmpty) {
    final byteLen = reader.varint();
    final flags = reader.byte();
    final fg = _readColor(reader, (flags >> _fgKindShift) & _kindMask);
    final bg = _readColor(reader, (flags >> _bgKindShift) & _kindMask);
    final attrs = flags & _attrsPresent == 0 ? CellAttrs.none : reader.varint();
    onRun(byteLen, fg, bg, attrs);
  }
}

/// Writes into [out] the bytes that draw [text] as [pen] describes it, every
/// run declaring the whole pen rather than a difference from the one before,
/// so a line replays without the ones above it having replayed first.
void penToAnsi(Uint8List text, Uint8List pen, ByteWriter out) {
  if (pen.isEmpty) {
    _writePlainPen(out);
    out.bytes(text);
    return;
  }

  var at = 0;
  readPen(pen, (byteLen, fg, bg, attrs) {
    if (at >= text.length) return;
    final end = at + byteLen > text.length ? text.length : at + byteLen;
    writeSgr(out, fg: fg, bg: bg, attrs: attrs);
    out.bytes(Uint8List.sublistView(text, at, end));
    at = end;
  });

  // Runs that fell short of the text still leave every byte on screen.
  if (at < text.length) {
    _writePlainPen(out);
    out.bytes(Uint8List.sublistView(text, at));
  }
}

/// The terminal's own pen, which is what an unrecorded line was drawn with.
void _writePlainPen(ByteWriter out) => writeSgr(
  out,
  fg: packedDefaultFg,
  bg: packedDefaultBg,
  attrs: CellAttrs.none,
);
