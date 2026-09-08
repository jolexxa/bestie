import 'package:terminal_screen/src/attrs.dart';
import 'package:terminal_screen/src/color.dart';

/// Which of the four [Color] variants a packed color holds.
enum ColorKind {
  /// The terminal's default foreground.
  defaultForeground,

  /// The terminal's default background.
  defaultBackground,

  /// One of the 256 palette entries; see [colorIndex].
  indexed,

  /// 24-bit truecolor; see [colorRed], [colorGreen], [colorBlue].
  rgb,
}

const int _kindShift = 24;

/// Pack [color] into the low 26 bits of an integer.
int packColor(Color color) => switch (color) {
  DefaultForeground() => ColorKind.defaultForeground.index << _kindShift,
  DefaultBackground() => ColorKind.defaultBackground.index << _kindShift,
  IndexedColor(:final index) => (ColorKind.indexed.index << _kindShift) | index,
  RgbColor(:final r, :final g, :final b) =>
    (ColorKind.rgb.index << _kindShift) | (r << 16) | (g << 8) | b,
};

/// [Color.defaultFg], pre-packed for use as a constant.
const int packedDefaultFg = 0 << _kindShift;

/// [Color.defaultBg], pre-packed for use as a constant.
const int packedDefaultBg = 1 << _kindShift;

/// The code for a blank cell's character: a single space.
const int blankCharCode = 0x20;

/// The style of a blank cell: no attributes, one column wide.
const int blankStyle = 1 << 10;

/// The variant [packed] holds.
ColorKind colorKind(int packed) =>
    ColorKind.values[(packed >> _kindShift) & 0x3];

/// The palette index of an [ColorKind.indexed] color.
int colorIndex(int packed) => packed & 0xFF;

/// The red channel of a [ColorKind.rgb] color.
int colorRed(int packed) => (packed >> 16) & 0xFF;

/// The green channel of a [ColorKind.rgb] color.
int colorGreen(int packed) => (packed >> 8) & 0xFF;

/// The blue channel of a [ColorKind.rgb] color.
int colorBlue(int packed) => packed & 0xFF;

/// The 256 palette colors, built once so unpacking an indexed color
/// hands back a shared instance rather than allocating.
final List<Color> _palette = List<Color>.generate(256, IndexedColor.new);

/// Rebuild the [Color] [packed] was made from.
///
/// Only [ColorKind.rgb] allocates; the other three hand back shared
/// instances.
Color unpackColor(int packed) => switch (colorKind(packed)) {
  ColorKind.defaultForeground => Color.defaultFg,
  ColorKind.defaultBackground => Color.defaultBg,
  ColorKind.indexed => _palette[colorIndex(packed)],
  ColorKind.rgb => RgbColor(
    colorRed(packed),
    colorGreen(packed),
    colorBlue(packed),
  ),
};

const int _widthShift = 10;
const int _attrsMask = 0x3FF;

/// Pack a [CellAttrs] bitfield and a [CellWidth] into 12 bits.
int packStyle({required int attrs, required CellWidth width}) =>
    (attrs & _attrsMask) | (width.index << _widthShift);

/// The [CellAttrs] bitfield held in [packed].
int styleAttrs(int packed) => packed & _attrsMask;

/// The [CellWidth] held in [packed].
CellWidth styleWidth(int packed) =>
    CellWidth.values[(packed >> _widthShift) & 0x3];

/// Single-character strings for the ASCII range, so decoding the
/// overwhelmingly common case hands back a shared instance instead of
/// building a new string per cell.
final List<String> _ascii = List<String>.generate(128, String.fromCharCode);

/// Encodes a cell's grapheme cluster as a single integer.
class GraphemeTable {
  static const int _spillFlag = 0x80000000;
  static const int _spillKeyMask = 0x7FFFFFFF;

  final List<String> _spilled = <String>[];
  final Map<String, int> _keys = <String, int>{};

  /// How many distinct multi-code-point clusters are held.
  int get spilledCount => _spilled.length;

  /// Encode [cluster] as an integer that [decode] reverses.
  int encode(String cluster) {
    if (cluster.isEmpty) return 0;
    if (cluster.length == 1) return cluster.codeUnitAt(0);
    final first = cluster.runes.first;
    // A lone code point above the BMP occupies two UTF-16 units.
    if (cluster.length == 2 && first > 0xFFFF) return first;

    final existing = _keys[cluster];
    if (existing != null) return existing;

    final key = _spilled.length | _spillFlag;
    _spilled.add(cluster);
    _keys[cluster] = key;
    return key;
  }

  /// Rebuild the cluster [code] was encoded from.
  String decode(int code) {
    if (code == 0) return '';
    if (code & _spillFlag != 0) return _spilled[code & _spillKeyMask];
    if (code < 128) return _ascii[code];
    return String.fromCharCode(code);
  }

  /// Drop every spilled cluster.
  void clear() {
    _spilled.clear();
    _keys.clear();
  }
}
