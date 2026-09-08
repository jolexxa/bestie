import 'dart:collection';

import 'package:katex_dart/katex_dart.dart';

/// Colour slots assigned to box-tree nodes, keyed by *identity*.
typedef MathTagging = Map<BoxNode, int>;

/// Assigns colour slots to a katex box tree.
typedef MathTagger = MathTagging Function(BoxNode root);

/// A fresh, correctly-keyed (identity, not `==`) tagging.
MathTagging newTagging() => HashMap<BoxNode, int>.identity();

/// Tags nothing — the off switch.
MathTagging tagNothing(BoxNode root) => const {};
