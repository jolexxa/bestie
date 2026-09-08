/// Markdown rendering with syntax-highlighted code blocks and diffs,
/// for nocterm.
library;

export 'package:math_render/math_render.dart'
    show MathTagger, tagNothing, tagSymbols;

export 'src/code_view.dart';
export 'src/diff_view.dart';
export 'src/languages.dart';
export 'src/markdown_builders.dart';
export 'src/markdown_view.dart';
export 'src/syntax_highlight.dart';
export 'src/theme/highlight_theme.dart';
export 'src/theme/markdown_theme.dart';
export 'src/theme/math_theme.dart';
export 'src/theme/math_theme_scope.dart';
