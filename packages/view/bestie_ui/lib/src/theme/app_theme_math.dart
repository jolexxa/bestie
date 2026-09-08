import 'package:bestie_ui/src/theme/app_theme.dart';
import 'package:markdown_highlighted/markdown_highlighted.dart';
import 'package:nocterm/nocterm.dart';

// The math styling types an app needs to install a scope, so a host does not
// have to reach for `markdown_highlighted` just to theme its equations.
export 'package:markdown_highlighted/markdown_highlighted.dart'
    show MathTheme, MathThemeScope, tagSymbols;

/// Math styling for an app theme: colour by identifier, drawn from the theme's
/// own palette.
extension AppThemeMath on AppThemeData {
  /// The math styling derived from this theme.
  MathTheme get math => MathTheme(
    tagger: tagSymbols,
    slotStyles: [
      TextStyle(color: primary),
      TextStyle(color: info),
      TextStyle(color: success),
      TextStyle(color: secondary),
    ],
  );
}
