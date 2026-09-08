/// Bitfield constants and helpers for `Cell.attrs`.
///
/// Packing the visual-attribute flags into a single `int` lets a
/// renderer compare two cells' styles with one equality check and
/// lets us pass an entire style through a function call without an
/// allocation. The layout is:
///
/// ```text
/// bit 0  : bold
/// bit 1  : faint
/// bit 2  : italic
/// bit 3  : blink
/// bit 4  : inverse
/// bit 5  : invisible
/// bit 6  : strikethrough
/// bits 7..9 : underline style (0 = off, 1 = single, 2 = double,
///             3 = curly, 4 = dotted, 5 = dashed)
/// ```
///
/// Everything else is zero; future flags claim bits 10+.
abstract final class CellAttrs {
  /// The empty attribute set — used on reset and for brand new cells.
  static const int none = 0;

  static const int _bold = 1 << 0;
  static const int _faint = 1 << 1;
  static const int _italic = 1 << 2;
  static const int _blink = 1 << 3;
  static const int _inverse = 1 << 4;
  static const int _invisible = 1 << 5;
  static const int _strikethrough = 1 << 6;
  static const int _underlineMask = 0x7 << 7;
  static const int _underlineShift = 7;

  /// `true` if the bold bit is set.
  static bool isBold(int attrs) => (attrs & _bold) != 0;

  /// `true` if the faint bit is set.
  static bool isFaint(int attrs) => (attrs & _faint) != 0;

  /// `true` if the italic bit is set.
  static bool isItalic(int attrs) => (attrs & _italic) != 0;

  /// `true` if the blink bit is set.
  static bool isBlink(int attrs) => (attrs & _blink) != 0;

  /// `true` if the inverse bit is set.
  static bool isInverse(int attrs) => (attrs & _inverse) != 0;

  /// `true` if the invisible bit is set.
  static bool isInvisible(int attrs) => (attrs & _invisible) != 0;

  /// `true` if the strikethrough bit is set.
  static bool isStrikethrough(int attrs) => (attrs & _strikethrough) != 0;

  /// The current underline style.
  static UnderlineStyle underlineStyle(int attrs) =>
      UnderlineStyle.values[(attrs & _underlineMask) >> _underlineShift];

  /// `true` if any underline style is active.
  static bool hasUnderline(int attrs) =>
      underlineStyle(attrs) != UnderlineStyle.off;

  /// Return [attrs] with the bold bit set to [value].
  static int setBold(int attrs, {bool value = true}) =>
      _toggle(attrs, _bold, value);

  /// Return [attrs] with the faint bit set to [value].
  static int setFaint(int attrs, {bool value = true}) =>
      _toggle(attrs, _faint, value);

  /// Return [attrs] with the italic bit set to [value].
  static int setItalic(int attrs, {bool value = true}) =>
      _toggle(attrs, _italic, value);

  /// Return [attrs] with the blink bit set to [value].
  static int setBlink(int attrs, {bool value = true}) =>
      _toggle(attrs, _blink, value);

  /// Return [attrs] with the inverse bit set to [value].
  static int setInverse(int attrs, {bool value = true}) =>
      _toggle(attrs, _inverse, value);

  /// Return [attrs] with the invisible bit set to [value].
  static int setInvisible(int attrs, {bool value = true}) =>
      _toggle(attrs, _invisible, value);

  /// Return [attrs] with the strikethrough bit set to [value].
  static int setStrikethrough(int attrs, {bool value = true}) =>
      _toggle(attrs, _strikethrough, value);

  /// Set the underline style ([style] must be in `0..5`). Style 0
  /// means "underline off."
  static int setUnderlineStyle(int attrs, int style) {
    assert(style >= 0 && style <= 5, 'underline style out of range');
    return (attrs & ~_underlineMask) | ((style & 0x7) << _underlineShift);
  }

  static int _toggle(int attrs, int bit, bool value) =>
      value ? (attrs | bit) : (attrs & ~bit);
}

/// A cell's role in the cluster it belongs to, which is also what
/// determines how many columns it covers.
enum CellWidth {
  /// The right half of a wide character — nothing of its own to draw.
  continuation,

  /// The common case.
  single,

  /// East Asian wide, or a double-width emoji.
  wide,

  /// The blank left at the right margin when the wide cluster that
  /// wanted it had to wrap instead.
  spacerHead;

  /// The width covering [columns], which must be 0, 1, or 2.
  static CellWidth ofColumns(int columns) => switch (columns) {
    0 => continuation,
    1 => single,
    _ => wide,
  };

  /// How many grid columns this cell covers.
  int get columns => switch (this) {
    continuation => 0,
    single || spacerHead => 1,
    wide => 2,
  };
}

/// The six underline styles SGR 4:N supports. Persisted as a 3-bit
/// field inside [CellAttrs].
enum UnderlineStyle {
  /// No underline (SGR 4:0 / 24).
  off,

  /// Single underline (SGR 4 / 4:1).
  single,

  /// Double underline (SGR 21 / 4:2).
  double_,

  /// Curly ("wavy") underline (SGR 4:3).
  curly,

  /// Dotted underline (SGR 4:4).
  dotted,

  /// Dashed underline (SGR 4:5).
  dashed,
}
