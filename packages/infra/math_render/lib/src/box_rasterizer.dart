import 'dart:math' as math;

import 'package:katex_dart/katex_dart.dart';
import 'package:math_render/src/math_grid.dart';
import 'package:math_render/src/raster_metrics.dart';
import 'package:math_render/src/tagging/box_atoms.dart';
import 'package:math_render/src/tagging/math_tagger.dart';

/// Walks a katex [BoxNode] tree and paints it onto a [MathGrid].
///
/// katex has already done the hard part — every node carries its em
/// dimensions, and vertical lists carry pre-resolved baseline shifts. This
/// rasterizer maps those continuous positions onto discrete cells: horizontal
/// advance becomes column packing, vertical shift becomes rows. On top of that
/// it synthesises the pieces katex leaves to a backend (its readme calls
/// stretchy-glyph stacking "incremental"): radicals, content-matched
/// delimiters, growable big operators, and accents.
class BoxRasterizer {
  /// Creates a rasterizer using [metrics] for the em-to-cell mapping, stamping
  /// cells with the colour slots in [tagging].
  const BoxRasterizer([
    this.metrics = const RasterMetrics(),
    this.tagging = const {},
  ]);

  /// The em-to-cell mapping used for this walk.
  final RasterMetrics metrics;

  /// Colour slots for the tree being walked.
  final MathTagging tagging;

  /// Rasterizes [node] into a grid aligned on its baseline.
  MathGrid rasterize(BoxNode node) => _rasterize(node, null);

  /// The slot [node] contributes, or [inherited] when it carries none of its
  /// own — so a tagger only marks where the answer changes.
  int? _slotOf(BoxNode node, int? inherited) => tagging[node] ?? inherited;

  MathGrid _rasterize(BoxNode node, int? inherited) {
    final slot = _slotOf(node, inherited);
    switch (node) {
      case GlyphNode(:final text):
        return MathGrid.line(text, slot);
      case KernNode(:final width):
        return _kern(width);
      case RuleNode(:final width):
        return MathGrid.line('─' * metrics.colsForRule(width), slot);
      case HBox(:final children):
        return _row(children, slot);
      case SpanNode(:final children):
        // An accented group is a span wrapping a single vertical list; if it
        // is ever shaped otherwise it is just a row, so the two share a path.
        final accent = isAccented(node) ? _soleNonKern(children) : null;
        return accent is VList
            ? _vlist(accent, _slotOf(accent, slot), deskew: true)
            : _row(children, slot);
      case VList():
        return _vlist(node, slot);
      case EncloseNode():
        return _enclose(node, slot);
      case ImageNode(:final alt):
        return MathGrid.line('[${alt.isEmpty ? 'img' : alt}]', slot);
      case SvgPathNode(:final pathName, :final width):
        return _svgPath(pathName, width, slot);
    }
  }

  /// Kerns are pure spacing, so their cells stay unslotted whatever slot the
  /// surrounding node carries — a run of colour should not extend through the
  /// gap katex sets around a binary operator.
  MathGrid _kern(double width) {
    final cols = metrics.colsForKern(width);
    return cols == 0 ? MathGrid.empty() : MathGrid.line(' ' * cols);
  }

  /// Surds and stretchy delimiters reach us as [SvgPathNode]s. Delimiters are
  /// intercepted at the row level and never arrive here; what remains are
  /// accents (a `\vec` arrow, a `\widetilde`), which we draw as a mark sized to
  /// the path's width. Anything else (a surd — handled by its VList) leaves an
  /// empty slot rather than noise.
  MathGrid _svgPath(String pathName, double width, int? slot) {
    final mark = _accentMark(pathName);
    if (mark == null) return MathGrid.empty();
    final cols = mark.stretch ? math.max(1, metrics.colsForRule(width)) : 1;
    return MathGrid.line(mark.symbol * cols, slot);
  }

  // --- Horizontal rows, with content-matched stretchy pieces -----------------

  MathGrid _row(List<BoxNode> children, int? inherited) {
    final grids = List<MathGrid?>.filled(children.length, null);
    final stretchy = <int, _Stretchy>{};
    var ascent = 0;
    var descent = 0;

    for (var i = 0; i < children.length; i++) {
      final piece = _stretchyFor(children[i], inherited);
      if (piece != null) {
        stretchy[i] = piece;
        continue;
      }
      final grid = _rasterize(children[i], inherited);
      grids[i] = grid;
      if (grid.ascent > ascent) ascent = grid.ascent;
      if (grid.descent > descent) descent = grid.descent;
    }

    for (final entry in stretchy.entries) {
      grids[entry.key] = entry.value(ascent, descent);
    }
    return MathGrid.beside(_separateMergers([for (final grid in grids) grid!]));
  }

  /// Inserts a one-cell gap between neighbours whose facing edges would fuse
  /// into a single stroke. A unary minus (`−`, U+2212) set straight against a
  /// fraction bar (`─`, U+2500) reads as one long dash — `−\frac{1}{2}` should
  /// stay legible. The gap is presentation only; TeX sets mathspace there too.
  List<MathGrid> _separateMergers(List<MathGrid> grids) {
    final result = <MathGrid>[];
    for (var i = 0; i < grids.length; i++) {
      if (i > 0 && _edgesMerge(grids[i - 1], grids[i])) {
        result.add(MathGrid.line(' '));
      }
      result.add(grids[i]);
    }
    return result;
  }

  /// Whether [left]'s right edge meets [right]'s left edge, on any row they
  /// share once aligned on their baselines, as a minus butting a fraction bar.
  bool _edgesMerge(MathGrid left, MathGrid right) {
    final ascent = math.max(left.ascent, right.ascent);
    final descent = math.max(left.descent, right.descent);
    final leftTop = ascent - left.ascent;
    final rightTop = ascent - right.ascent;
    for (var y = 0; y < ascent + descent + 1; y++) {
      final li = y - leftTop;
      final ri = y - rightTop;
      if (li < 0 || li >= left.height) continue;
      if (ri < 0 || ri >= right.height) continue;
      if (_lastCluster(left.cells[li]) == '−' &&
          _firstCluster(right.cells[ri]) == '─') {
        return true;
      }
    }
    return false;
  }

  String? _lastCluster(List<MathCell> row) =>
      row.isEmpty ? null : row.last.cluster;

  String? _firstCluster(List<MathCell> row) =>
      row.isEmpty ? null : row.first.cluster;

  /// A stretchy delimiter or growable operator for [node], or null when it is
  /// ordinary content.
  ///
  /// `\left`/`\right` delimiters arrive as bracket glyphs in a `Size*` font or
  /// as delimiter [SvgPathNode]s (`vert`, `lparen`, …); display big operators
  /// arrive as `Size2` glyphs — all wrapped in single-child spans/lists.
  _Stretchy? _stretchyFor(BoxNode node, int? inherited) {
    final core = _unwrap(node);
    if (core is GlyphNode) {
      if (core.font.fontName.startsWith('Size')) {
        final delimiter = _delimiters[core.text];
        if (delimiter != null) return delimiter.build;
      }
      if (core.font.fontName == _displayOperatorFont) {
        return _operators[core.text]?.build;
      }
    } else if (core is SvgPathNode) {
      return _delimiterPaths[core.pathName]?.build;
    } else if (core is VList) {
      return _mopFor(core, _slotOf(node, inherited))?.build;
    }
    return null;
  }

  /// Detects a big operator carrying over/under limits — a [VList] with the
  /// operator glyph in the middle and its limits above and below — so the whole
  /// unit can grow together: the operator stretches to the operand and the
  /// limits re-stack tight against the grown glyph.
  _Mop? _mopFor(VList vlist, int? inherited) {
    int? operatorIndex;
    _Operator? operator;
    for (var i = 0; i < vlist.positions.length; i++) {
      final core = _unwrap(vlist.positions[i].box);
      if (core is GlyphNode && core.font.fontName == _displayOperatorFont) {
        final candidate = _operators[core.text];
        if (candidate != null) {
          operatorIndex = i;
          operator = candidate;
          break;
        }
      }
    }
    if (operator == null) return null;

    BoxNode? upperBox;
    BoxNode? lowerBox;
    var upperShift = 0.0;
    var lowerShift = 0.0;
    for (var i = 0; i < vlist.positions.length; i++) {
      if (i == operatorIndex) continue;
      final position = vlist.positions[i];
      if (position.shift < upperShift) {
        upperShift = position.shift;
        upperBox = position.box;
      }
      if (position.shift > lowerShift) {
        lowerShift = position.shift;
        lowerBox = position.box;
      }
    }
    return _Mop(
      operator,
      upperBox == null ? null : _limit(upperBox, inherited),
      lowerBox == null ? null : _limit(lowerBox, inherited),
    );
  }

  /// Peels off single-child spans, boxes, and lists to reach the glyph or path
  /// a delimiter/operator is wrapped in. Kerns are treated as skippable padding,
  /// so a big operator that katex brackets with centering kerns (which it does
  /// when its limits are wider than the glyph, e.g. a `\substack` under a `∏`)
  /// still unwraps to its glyph.
  BoxNode _unwrap(BoxNode node) {
    var current = node;
    while (true) {
      if (current is SpanNode) {
        final core = _soleNonKern(current.children);
        if (core == null) return current;
        current = core;
      } else if (current is HBox) {
        final core = _soleNonKern(current.children);
        if (core == null) return current;
        current = core;
      } else if (current is VList && current.positions.length == 1) {
        current = current.positions.first.box;
      } else {
        return current;
      }
    }
  }

  /// The single non-kern child of [children], or null when there are none or
  /// several.
  BoxNode? _soleNonKern(List<BoxNode> children) {
    BoxNode? sole;
    for (final child in children) {
      if (child is KernNode) continue;
      if (sole != null) return null;
      sole = child;
    }
    return sole;
  }

  /// Rasterizes an over/under limit for a big operator. A limit that is itself a
  /// vertical stack (a `\substack`) keeps its rows tight against each other
  /// rather than nudged apart the way a bare subscript is lifted off its base,
  /// so its own vlist skips that nudge.
  MathGrid _limit(BoxNode box, int? inherited) {
    final core = _unwrap(box);
    final slot = _slotOf(box, inherited);
    return core is VList
        ? _vlist(core, _slotOf(core, slot), nudge: false)
        : _rasterize(box, inherited);
  }

  // --- Vertical lists: fractions, scripts, roots, big-op limits, accents ---

  /// Lays a vertical list out on the grid.
  ///
  /// [deskew] drops the leading kern katex offsets an accent mark by. That kern
  /// optically centres the mark over a sloped letter — 0.221em for an `H`,
  /// 0.085em for a `p`. Both are a fraction of a cell, but rounding sends the
  /// first to a whole column and the second to none, so `\hat{H}` would set its
  /// caret over the blank beside the letter while `\hat{p}` sat right. Sub-cell
  /// optical centring has no meaning on a character grid; centring the mark on
  /// the letter does.
  MathGrid _vlist(
    VList node,
    int? inherited, {
    bool nudge = true,
    bool deskew = false,
  }) {
    if (node.positions.isEmpty) return MathGrid.empty();
    if (node.positions.any(_isSurd)) return _sqrt(node, inherited);

    // Place the elements closest to the baseline first, then push any whose row
    // spans (ascent..descent) would overlap an already-placed element outward.
    // This keeps a fraction bar clear of a two-row numerator/denominator's
    // overhang and lifts a zero-shift accent off its base. Ties break by
    // position index: katex lists vlist children bottom-to-top, so a zero-shift
    // accent (index above its base) is placed second and bumps upward.
    final order = List.generate(node.positions.length, (i) => i)
      ..sort((a, b) {
        final byShift = node.positions[a].shift.abs().compareTo(
          node.positions[b].shift.abs(),
        );
        return byShift != 0 ? byShift : a.compareTo(b);
      });
    final occupied = <int>{};
    final builder = MathGridBuilder();
    for (final i in order) {
      final position = node.positions[i];
      final box = deskew ? _stripLeadingKern(position.box) : position.box;
      final grid = _rasterize(box, inherited);
      final step = position.shift > 0 ? 1 : -1;
      var row = metrics.rowForShift(position.shift);
      // A script with a small but nonzero shift (a bare subscript at 0.15em)
      // rounds onto the baseline and merges with its base; nudge it off. Guard
      // with a threshold so a base at floating-point ±0 (e.g. a `\lim`) is left
      // put, and skip rules (a fraction bar legitimately sits on the axis).
      if (nudge &&
          row == 0 &&
          position.shift.abs() > 0.05 &&
          position.box is! RuleNode) {
        row = step;
      }
      while (_overlaps(occupied, row, grid)) {
        row += step;
      }
      for (var r = row - grid.ascent; r <= row + grid.descent; r++) {
        occupied.add(r);
      }
      final child = position.box;
      final stretch = child is RuleNode && child.width > 0 ? '─' : null;
      builder.placeCentered(grid, row, stretchAs: stretch);
    }
    return builder.build();
  }

  /// Whether a grid placed at [row] (spanning its ascent above and descent
  /// below) would land on any already-[occupied] row.
  bool _overlaps(Set<int> occupied, int row, MathGrid grid) {
    for (var r = row - grid.ascent; r <= row + grid.descent; r++) {
      if (occupied.contains(r)) return true;
    }
    return false;
  }

  bool _isSurd(VListPosition position) =>
      position.box is SvgPathNode &&
      (position.box as SvgPathNode).pathName.startsWith('sqrt');

  MathGrid _sqrt(VList node, int? inherited) {
    final radicand = node.positions.firstWhere((p) => !_isSurd(p)).box;
    return _radical(_rasterize(_stripLeadingKern(radicand), inherited));
  }

  /// Drops a leading kern — the space katex reserves for a surd glyph we redraw
  /// ourselves, or the skew it offsets an accent mark by.
  BoxNode _stripLeadingKern(BoxNode box) {
    if (box is HBox &&
        box.children.isNotEmpty &&
        box.children.first is KernNode) {
      return HBox(box.children.sublist(1));
    }
    return box;
  }

  /// Wraps [radicand] in a radical sign: a `╲` hook at the bottom-left, a
  /// straight vertical stem rising up the left edge, and a top corner turning
  /// into the vinculum drawn across the radicand's top. The stem stays vertical
  /// at any height rather than leaning.
  MathGrid _radical(MathGrid radicand) {
    final height = radicand.height;
    return MathGrid.fromCells([
      _drawnRow(' ┌${'─' * radicand.width}'),
      for (var i = 0; i < height; i++)
        [
          ..._drawnRow(i == height - 1 ? '╲│' : ' │'),
          ...radicand.cells[i],
        ],
    ], radicand.baseline + 1);
  }

  // --- Enclosures ------------------------------------------------------------

  MathGrid _enclose(EncloseNode node, int? inherited) {
    final inner = _rasterize(node.child, inherited);
    if (!node.notations.contains(EncloseNotation.box)) return inner;

    // katex pads the boxed content with fboxsep struts, which round to blank
    // rows that land unevenly (all on top) for content taller than one row.
    // Re-centre that padding so the frame hugs the content symmetrically.
    var first = 0;
    var last = inner.height - 1;
    while (first < last && _isBlankRow(inner.cells[first])) {
      first++;
    }
    while (last > first && _isBlankRow(inner.cells[last])) {
      last--;
    }
    final pad = inner.height - (last - first + 1);
    final topPad = pad ~/ 2;
    final width = inner.width;
    final blank = List.filled(width, MathCell.space);
    final rows = [
      for (var i = 0; i < topPad; i++) blank,
      for (var i = first; i <= last; i++) inner.cells[i],
      for (var i = 0; i < pad - topPad; i++) blank,
    ];
    final side = _drawnRow('│');
    return MathGrid.fromCells([
      _drawnRow('┌${'─' * width}┐'),
      for (final row in rows) [...side, ...row, ...side],
      _drawnRow('└${'─' * width}┘'),
    ], inner.baseline - first + topPad + 1);
  }

  bool _isBlankRow(List<MathCell> row) => row.every((cell) => cell.isSpace);

  /// Cells for structure the renderer draws itself — a radical's stem, an
  /// enclosing frame. These have no box node behind them, so no tagger can
  /// claim them and they stay unslotted.
  List<MathCell> _drawnRow(String text) => MathGrid.line(text).cells.first;
}

/// The katex font big operators use at display size; the inline `Size1` variant
/// stays a single glyph.
const _displayOperatorFont = 'Size2-Regular';

/// Something that grows to span `ascent` rows above the baseline and `descent`
/// below it, from a Unicode piece set — a delimiter or a big operator.
typedef _Stretchy = MathGrid Function(int ascent, int descent);

/// A stretchy delimiter. Shrinks to fit its content exactly (a `\left(` around
/// a single symbol is just `(`) and grows without bound via its [ext] piece.
class _Delimiter {
  const _Delimiter(
    this.single,
    this.top,
    this.ext,
    this.bottom, [
    this.mid,
  ]);

  final String single;
  final String top;
  final String ext;
  final String bottom;
  final String? mid;

  MathGrid build(int ascent, int descent) {
    final rows = ascent + descent + 1;
    if (rows <= 1) return MathGrid.line(single);
    if (rows == 2) {
      return MathGrid.fromRows([top, bottom], ascent);
    }
    return MathGrid.fromRows(
      [
        for (var r = 0; r < rows; r++)
          if (r == 0)
            top
          else if (r == rows - 1)
            bottom
          else if (mid != null && r == ascent)
            mid!
          else
            ext,
      ],
      ascent,
    );
  }
}

/// A big operator (∑, ∫, ∏, …). Unlike a delimiter it has a minimum display
/// size (it stays enlarged even over a small operand) but grows to wrap a
/// taller one — when Unicode gives it an [ext] piece. Sums have no extender, so
/// they stay a fixed two-row glyph.
class _Operator {
  const _Operator({
    required this.top,
    required this.bottom,
    required this.minAscent,
    required this.minDescent,
    this.ext,
  });

  final String top;
  final String bottom;
  final String? ext;
  final int minAscent;
  final int minDescent;

  MathGrid build(int ascent, int descent) {
    final asc = math.max(minAscent, ascent);
    final desc = math.max(minDescent, descent);
    final rows = asc + desc + 1;
    return MathGrid.fromRows(
      [
        for (var r = 0; r < rows; r++)
          if (r == 0) top else if (r == rows - 1) bottom else ext!,
      ],
      asc,
    );
  }
}

/// A big operator carrying over/under limits. Grows the operator to the operand
/// (via [_Operator.build]) then re-stacks the pre-rendered [upper]/[lower]
/// limits tight against the grown glyph, replacing katex's fixed limit shifts
/// (which assumed the small glyph).
class _Mop {
  const _Mop(this.operator, this.upper, this.lower);

  final _Operator operator;
  final MathGrid? upper;
  final MathGrid? lower;

  MathGrid build(int ascent, int descent) =>
      _stackAround(upper, operator.build(ascent, descent), lower);
}

/// Stacks [body] with [upper] centred just above it and [lower] just below,
/// keeping [body]'s baseline. Used to place big-operator limits.
MathGrid _stackAround(MathGrid? upper, MathGrid body, MathGrid? lower) {
  final builder = MathGridBuilder()..placeCentered(body, 0);
  if (upper != null) {
    builder.placeCentered(upper, -body.ascent - 1 - upper.descent);
  }
  if (lower != null) {
    builder.placeCentered(lower, body.descent + 1 + lower.ascent);
  }
  return builder.build();
}

/// The most diagonals the summation's beak leans before extra height is spent
/// on the straight spine instead. Capped at one so the beak stays a tidy
/// arrowhead and the glyph never grows past four cells wide.
const _maxSigmaArm = 1;

/// The summation operator. Unicode ships only a two-row glyph (⎲ over ⎳); above
/// that we draw the sigma ourselves.
///
/// - 2–3 rows: the `⎲`/`⎳` end-caps, joined by a `│` spine at 3 rows.
/// - 4+ rows: box corners top and bottom, a straight `│` spine at the left
///   edge, and the arm as a *detached* beak floating one cell in — so the
///   vertical never shares a row with a diagonal and the point pokes out right.
///
/// The beak arm is capped at [_maxSigmaArm]; any further height is spent on
/// plain spine rows, so a tall sum stays a narrow column tapering to the point.
/// Odd heights tip the beak with `>`; even heights meet it blunt as `╲`/`╱`,
/// and because that blunt tip is a row taller it takes one more row of height
/// before the arm extends — so an even sum's beak grows a step behind the odd
/// ones. Once a spine is present the bar runs one cell past the tip.
class _SumOperator extends _Operator {
  const _SumOperator()
    : super(top: '⎲', bottom: '⎳', minAscent: 1, minDescent: 0);

  @override
  MathGrid build(int ascent, int descent) {
    final rows = math.max(2, ascent + descent + 1);
    final baseline = math.max(minAscent, ascent);
    if (rows <= 2) {
      return MathGrid.fromRows([top, bottom], baseline);
    }
    // The caps already bend; a 3-row sum just needs a straight spine between.
    if (rows == 3) {
      return MathGrid.fromRows([top, '│', bottom], baseline);
    }

    final interior = rows - 2;
    final odd = interior.isOdd;
    final vertexRows = odd ? 1 : 2;
    final half = (interior - vertexRows) ~/ 2;
    // The blunt even tip is a row taller, so it reaches the arm a `half` late.
    final arm = odd
        ? math.min(half, _maxSigmaArm)
        : math.min(math.max(half - 1, 0), _maxSigmaArm);
    final straight = half - arm;
    final tip = arm + 1;
    final overhang = straight > 0;
    final width = tip + 1 + (overhang ? 1 : 0);
    // With a spine the bar overhangs the tip by one; cap that end with a serif
    // tick (`┐`/`┘`) so the top and bottom read as a sigma's stroke ends.
    final rule = '─' * (width - 1);
    final topBar = overhang ? '┌${'─' * (width - 2)}┐' : '┌$rule';
    final bottomBar = overhang ? '└${'─' * (width - 2)}┘' : '└$rule';
    final vertex = odd
        ? [_edgeRow('>', tip, width)]
        : [_edgeRow('╲', tip, width), _edgeRow('╱', tip, width)];
    return MathGrid.fromRows(
      [
        topBar,
        for (var i = 0; i < straight; i++) _spineRow(width),
        for (var k = 1; k <= arm; k++) _edgeRow('╲', k, width),
        ...vertex,
        for (var k = arm; k >= 1; k--) _edgeRow('╱', k, width),
        for (var i = 0; i < straight; i++) _spineRow(width),
        bottomBar,
      ],
      baseline,
    );
  }

  /// A lone spine cell: the straight `│` at the left edge.
  String _spineRow(int width) => '│${' ' * (width - 1)}';

  /// A single [stroke] set [indent] cells in, padded to [width]; blank left of
  /// it, so a beak drawn this way is detached from the spine.
  String _edgeRow(String stroke, int indent, int width) =>
      ' ' * indent + stroke + ' ' * (width - indent - 1);
}

/// An accent mark synthesised from a katex accent [SvgPathNode]. [stretch]
/// marks accents that widen to cover their base (a `\widetilde`) versus fixed
/// ones (a `\vec` arrow).
class _AccentMark {
  const _AccentMark(this.symbol, {this.stretch = false});

  final String symbol;
  final bool stretch;
}

/// Resolves the accent [SvgPathNode] path name to a mark, or null when it is
/// not an accent (e.g. a surd path).
_AccentMark? _accentMark(String pathName) {
  if (pathName.startsWith('tilde')) {
    return const _AccentMark('~', stretch: true);
  }
  if (pathName.startsWith('widehat')) {
    return const _AccentMark('^', stretch: true);
  }
  if (pathName == 'vec') return const _AccentMark('→');
  if (pathName.contains('rightarrow')) return const _AccentMark('→');
  if (pathName.contains('leftarrow')) return const _AccentMark('←');
  return null;
}

const _delimiters = <String, _Delimiter>{
  '(': _Delimiter('(', '⎛', '⎜', '⎝'),
  ')': _Delimiter(')', '⎞', '⎟', '⎠'),
  '[': _Delimiter('[', '⎡', '⎢', '⎣'),
  ']': _Delimiter(']', '⎤', '⎥', '⎦'),
  '{': _Delimiter('{', '⎧', '⎪', '⎩', '⎨'),
  '}': _Delimiter('}', '⎫', '⎪', '⎭', '⎬'),
  '|': _Delimiter('|', '│', '│', '│'),
  '‖': _Delimiter('‖', '║', '║', '║'),
  '⌊': _Delimiter('⌊', '⎢', '⎢', '⌊'),
  '⌋': _Delimiter('⌋', '⎥', '⎥', '⌋'),
  '⌈': _Delimiter('⌈', '⌈', '⎢', '⎢'),
  '⌉': _Delimiter('⌉', '⌉', '⎥', '⎥'),
};

/// Delimiters katex renders as stacked geometry ([SvgPathNode]) rather than a
/// font glyph — vertical bars, and any bracket taller than its `Size4` glyph.
const _delimiterPaths = <String, _Delimiter>{
  'vert': _Delimiter('|', '│', '│', '│'),
  'doublevert': _Delimiter('‖', '║', '║', '║'),
  'lparen': _Delimiter('(', '⎛', '⎜', '⎝'),
  'rparen': _Delimiter(')', '⎞', '⎟', '⎠'),
  'lbrack': _Delimiter('[', '⎡', '⎢', '⎣'),
  'rbrack': _Delimiter(']', '⎤', '⎥', '⎣'),
  'lfloor': _Delimiter('⌊', '⎢', '⎢', '⌊'),
  'rfloor': _Delimiter('⌋', '⎥', '⎥', '⌋'),
  'lceil': _Delimiter('⌈', '⌈', '⎢', '⎢'),
  'rceil': _Delimiter('⌉', '⌉', '⎥', '⎥'),
};

const _operators = <String, _Operator>{
  '∑': _SumOperator(),
  '∫': _Operator(
    top: '⌠',
    ext: '⎮',
    bottom: '⌡',
    minAscent: 1,
    minDescent: 1,
  ),
  '∮': _Operator(
    top: '⌠',
    ext: '⎮',
    bottom: '⌡',
    minAscent: 1,
    minDescent: 1,
  ),
  '∏': _Operator(
    top: '┬─┬',
    ext: '│ │',
    bottom: '┘ └',
    minAscent: 2,
    minDescent: 0,
  ),
  '∐': _Operator(
    top: '┌─┐',
    ext: '│ │',
    bottom: '┴ ┴',
    minAscent: 2,
    minDescent: 0,
  ),
  '⋃': _Operator(
    top: '│ │',
    ext: '│ │',
    bottom: '└─┘',
    minAscent: 2,
    minDescent: 0,
  ),
  '⋂': _Operator(
    top: '┌─┐',
    ext: '│ │',
    bottom: '│ │',
    minAscent: 2,
    minDescent: 0,
  ),
};
