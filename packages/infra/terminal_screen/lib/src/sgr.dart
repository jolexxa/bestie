import 'package:terminal_screen/src/attrs.dart';
import 'package:terminal_screen/src/color.dart';

/// Mutable pen state: the current foreground / background colors
/// and attribute bitfield that will be applied to printed cells.
class Pen {
  /// Current foreground color.
  Color fg = Color.defaultFg;

  /// Current background color.
  Color bg = Color.defaultBg;

  /// Current attribute bitfield (see `CellAttrs`).
  int attrs = 0;

  /// Reset to defaults (SGR 0).
  void reset() {
    fg = Color.defaultFg;
    bg = Color.defaultBg;
    attrs = 0;
  }
}

/// Apply a CSI SGR sequence's parameters to [pen]. [params] is the
/// structure vt_parser hands us: each top-level entry is a
/// parameter, and the inner list is its `:`-separated subparams
/// (e.g. `38:2:255:0:0` parses to a single parameter with five
/// subparameter values).
///
/// Unknown or explicitly skipped codes are silently ignored; the
/// behaviour matches xterm.
void applySgr(Pen pen, List<List<int>> params) {
  if (params.isEmpty) {
    pen.reset();
    return;
  }
  var i = 0;
  while (i < params.length) {
    final group = params[i];
    final code = group.isEmpty ? 0 : group.first;

    switch (code) {
      case 0:
        pen.reset();
      case 1:
        pen.attrs = CellAttrs.setBold(pen.attrs);
      case 2:
        pen.attrs = CellAttrs.setFaint(pen.attrs);
      case 3:
        pen.attrs = CellAttrs.setItalic(pen.attrs);
      case 4:
        // `4` alone is single underline. `4:N` via a subparameter
        // group selects style 0..5.
        if (group.length >= 2) {
          pen.attrs = CellAttrs.setUnderlineStyle(pen.attrs, group[1]);
        } else {
          pen.attrs = CellAttrs.setUnderlineStyle(pen.attrs, 1);
        }
      case 5:
      case 6:
        pen.attrs = CellAttrs.setBlink(pen.attrs);
      case 7:
        pen.attrs = CellAttrs.setInverse(pen.attrs);
      case 8:
        pen.attrs = CellAttrs.setInvisible(pen.attrs);
      case 9:
        pen.attrs = CellAttrs.setStrikethrough(pen.attrs);
      case 21:
        // SGR 21 is "double underline" historically, which maps
        // to underline style 2 in our 4:N scheme.
        pen.attrs = CellAttrs.setUnderlineStyle(pen.attrs, 2);
      case 22:
        pen.attrs = CellAttrs.setBold(pen.attrs, value: false);
        pen.attrs = CellAttrs.setFaint(pen.attrs, value: false);
      case 23:
        pen.attrs = CellAttrs.setItalic(pen.attrs, value: false);
      case 24:
        pen.attrs = CellAttrs.setUnderlineStyle(pen.attrs, 0);
      case 25:
        pen.attrs = CellAttrs.setBlink(pen.attrs, value: false);
      case 27:
        pen.attrs = CellAttrs.setInverse(pen.attrs, value: false);
      case 28:
        pen.attrs = CellAttrs.setInvisible(pen.attrs, value: false);
      case 29:
        pen.attrs = CellAttrs.setStrikethrough(pen.attrs, value: false);
      case 30:
      case 31:
      case 32:
      case 33:
      case 34:
      case 35:
      case 36:
      case 37:
        pen.fg = IndexedColor(code - 30);
      case 38:
        // Extended foreground. Two forms:
        //   SGR 38 : 2 : r : g : b   (single subparam group)
        //   SGR 38 ; 2 ; r ; g ; b   (multi group; consume them)
        //   SGR 38 : 5 : index
        //   SGR 38 ; 5 ; index
        final parsed = _parseExtendedColor(params, i, group);
        if (parsed != null) {
          pen.fg = parsed.color;
          i = parsed.nextIndex;
          continue;
        }
      case 39:
        pen.fg = Color.defaultFg;
      case 40:
      case 41:
      case 42:
      case 43:
      case 44:
      case 45:
      case 46:
      case 47:
        pen.bg = IndexedColor(code - 40);
      case 48:
        final parsed = _parseExtendedColor(params, i, group);
        if (parsed != null) {
          pen.bg = parsed.color;
          i = parsed.nextIndex;
          continue;
        }
      case 49:
        pen.bg = Color.defaultBg;
      case 58:
        // Underline color — parse but only apply if we had a
        // place to store it. Our `attrs` bitfield doesn't carry
        // a separate underline color yet, so we parse to advance
        // the index but otherwise drop the value.
        final parsed = _parseExtendedColor(params, i, group);
        if (parsed != null) {
          i = parsed.nextIndex;
          continue;
        }
      case 59:
        // Default underline color — no-op for us.
        break;
      case 90:
      case 91:
      case 92:
      case 93:
      case 94:
      case 95:
      case 96:
      case 97:
        pen.fg = IndexedColor(code - 90 + 8);
      case 100:
      case 101:
      case 102:
      case 103:
      case 104:
      case 105:
      case 106:
      case 107:
        pen.bg = IndexedColor(code - 100 + 8);
      default:
        // Silently skip font selection (10..20), framed /
        // encircled / overlined (50..55), ideogram decorations
        // (60..65), and anything else we don't recognise. This
        // matches xterm's "tolerate unknown SGR" behaviour.
        break;
    }
    i += 1;
  }
}

/// Try to parse an extended-color sequence starting at index [i]
/// in [params], where [group] is `params[i]` (the top-level param
/// with value 38, 48, or 58). Handles both the subparam form
/// (values inside [group] after the leading 38/48/58) and the
/// legacy form (subsequent top-level groups are the extension).
///
/// Returns the parsed color + the next index to resume at, or
/// `null` if the sequence is malformed (caller should advance by
/// one and keep going).
({Color color, int nextIndex})? _parseExtendedColor(
  List<List<int>> params,
  int i,
  List<int> group,
) {
  // Subparam form: group = [38, kind, a, b, c]
  if (group.length >= 2) {
    final kind = group[1];
    if (kind == 2) {
      // Truecolor. Some emitters use 38:2:R:G:B, some use
      // 38:2:colorSpace:R:G:B (6 entries). Handle both.
      if (group.length >= 6) {
        return (
          color: RgbColor(group[3], group[4], group[5]),
          nextIndex: i + 1,
        );
      }
      if (group.length >= 5) {
        return (
          color: RgbColor(group[2], group[3], group[4]),
          nextIndex: i + 1,
        );
      }
      return null;
    }
    if (kind == 5 && group.length >= 3) {
      return (color: IndexedColor(group[2]), nextIndex: i + 1);
    }
    return null;
  }

  // Legacy top-level form: 38 ; kind ; …
  if (i + 1 >= params.length) return null;
  final kindGroup = params[i + 1];
  if (kindGroup.isEmpty) return null;
  final kind = kindGroup.first;
  if (kind == 5) {
    if (i + 2 >= params.length) return null;
    final idxGroup = params[i + 2];
    if (idxGroup.isEmpty) return null;
    return (
      color: IndexedColor(idxGroup.first),
      nextIndex: i + 3,
    );
  }
  if (kind == 2) {
    if (i + 4 >= params.length) return null;
    final rg = params[i + 2];
    final gg = params[i + 3];
    final bg = params[i + 4];
    if (rg.isEmpty || gg.isEmpty || bg.isEmpty) return null;
    return (
      color: RgbColor(rg.first, gg.first, bg.first),
      nextIndex: i + 5,
    );
  }
  return null;
}
