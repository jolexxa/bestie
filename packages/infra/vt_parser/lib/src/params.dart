// Ported from alacritty/vte's `src/params.rs`. Upstream copyright
// (c) 2016 Joe Wilm; original license MIT / Apache-2.0. See
// ../../THIRD_PARTY_NOTICES.md.
import 'package:meta/meta.dart';
import 'package:vt_parser/src/constants.dart';

/// Fixed-capacity parameter list with ITU-T T.416 subparameter
/// (`:`-separated) support. Ported verbatim from
/// `alacritty/vte`'s `Params` struct at `src/params.rs`.
///
/// A CSI sequence like `CSI 38:2:255:0:0;1m` parses to two
/// parameters: `[38, 2, 255, 0, 0]` (a single parameter with four
/// subparameters) and `[1]` (a single parameter with no subparams).
/// `toList` yields one `List<int>` per top-level parameter.
///
/// Internally we use the same clever two-array layout as vte:
///
///   * A flat values array stores every parameter value in order.
///   * At the index where a parameter group *starts*, a parallel
///     "subparams" array stores the total length of that group
///     (in slots); the slots after the start are zero.
///
/// This keeps both mutation and iteration O(1) per step without any
/// nested allocations.
class Params {
  /// Lengths of each parameter group, keyed at the group's starting
  /// index into the flat values array. All other slots are zero.
  final List<int> _subparams = List<int>.filled(maxParams, 0);

  /// All parameter values (including subparameter values) in order.
  final List<int> _values = List<int>.filled(maxParams, 0);

  /// Number of subparameters that have been pushed into the current
  /// (still-open) parameter group. Reset to zero when a new
  /// parameter group begins.
  int _currentSubparams = 0;

  /// Total number of values stored so far (main + subparams).
  int _len = 0;

  /// `true` once the flat values array has filled up; additional
  /// pushes are dropped and the caller should set its `ignore` flag.
  @internal
  bool get isFull => _len == maxParams;

  /// Reset to the empty state. Reused across dispatches so that the
  /// underlying storage doesn't reallocate.
  @internal
  void clear() {
    _currentSubparams = 0;
    _len = 0;
  }

  /// Push a new top-level parameter with the given value. Closes
  /// any currently-open subparameter group.
  @internal
  void push(int value) {
    _subparams[_len - _currentSubparams] = _currentSubparams + 1;
    _values[_len] = value;
    _currentSubparams = 0;
    _len += 1;
  }

  /// Add a subparameter to the currently-open parameter group.
  @internal
  void extend(int value) {
    _subparams[_len - _currentSubparams] = _currentSubparams + 1;
    _values[_len] = value;
    _currentSubparams += 1;
    _len += 1;
  }

  /// Snapshot the current contents as a fresh
  /// `List<List<int>>`. Outer entries are parameter groups; inner
  /// entries are the subparameters of each group (length >= 1 for
  /// every entry yielded). Safe to retain.
  List<List<int>> toList() {
    final out = <List<int>>[];
    var i = 0;
    while (i < _len) {
      final n = _subparams[i];
      out.add(_values.sublist(i, i + n));
      i += n;
    }
    return out;
  }
}
