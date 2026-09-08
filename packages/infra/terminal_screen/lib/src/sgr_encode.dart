import 'package:byte_codec/byte_codec.dart';
import 'package:terminal_screen/src/attrs.dart';
import 'package:terminal_screen/src/packed_cell.dart';

const int _escape = 0x1B;
const int _bracket = 0x5B;
const int _semicolon = 0x3B;
const int _colon = 0x3A;
const int _finalByte = 0x6D;
const int _zero = 0x30;

/// Writes into [out] the SGR sequence that sets the pen [fg] / [bg] / [attrs]
/// describes, starting from a reset.
///
/// The inverse of `applySgr`, and written as bytes because that is what it is:
/// replaying a recording means handing these to the same parser that drew the
/// output the first time, and a string in between would be built only to be
/// taken apart again a character at a time.
void writeSgr(
  ByteWriter out, {
  required int fg,
  required int bg,
  required int attrs,
}) {
  out
    ..byte(_escape)
    ..byte(_bracket)
    ..byte(_zero);
  if (CellAttrs.isBold(attrs)) _parameter(out, 1);
  if (CellAttrs.isFaint(attrs)) _parameter(out, 2);
  if (CellAttrs.isItalic(attrs)) _parameter(out, 3);
  if (CellAttrs.isBlink(attrs)) _parameter(out, 5);
  if (CellAttrs.isInverse(attrs)) _parameter(out, 7);
  if (CellAttrs.isInvisible(attrs)) _parameter(out, 8);
  if (CellAttrs.isStrikethrough(attrs)) _parameter(out, 9);
  final underline = CellAttrs.underlineStyle(attrs);
  if (underline != UnderlineStyle.off) {
    _parameter(out, 4);
    out.byte(_colon);
    _number(out, underline.index);
  }
  _writeColor(out, fg, base: 38);
  _writeColor(out, bg, base: 48);
  out.byte(_finalByte);
}

/// The parameters selecting [packed] as a [base] (38 foreground, 48
/// background) colour. A default carries none: the reset already set it.
void _writeColor(ByteWriter out, int packed, {required int base}) {
  switch (colorKind(packed)) {
    case ColorKind.defaultForeground:
    case ColorKind.defaultBackground:
      return;
    case ColorKind.indexed:
      _parameter(out, base);
      _parameter(out, 5);
      _parameter(out, colorIndex(packed));
    case ColorKind.rgb:
      _parameter(out, base);
      _parameter(out, 2);
      _parameter(out, colorRed(packed));
      _parameter(out, colorGreen(packed));
      _parameter(out, colorBlue(packed));
  }
}

/// One more parameter, after the separator that joins it to the last.
void _parameter(ByteWriter out, int value) {
  out.byte(_semicolon);
  _number(out, value);
}

/// [value] in decimal, most significant digit first.
void _number(ByteWriter out, int value) {
  if (value >= 10) _number(out, value ~/ 10);
  out.byte(_zero + value % 10);
}
