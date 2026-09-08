import 'package:terminal_screen/src/attrs.dart';
import 'package:terminal_screen/src/color.dart';

/// An immutable snapshot of a cell's state.
typedef CellData = ({
  String char,
  Color fg,
  Color bg,
  int attrs,
  CellWidth width,
});
