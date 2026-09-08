import 'package:markdown_highlighted/src/theme/math_theme.dart';
import 'package:nocterm/nocterm.dart';

/// Carries the [MathTheme] in effect down the tree, so a `MarkdownView` picks
/// it up without every call site resolving one itself.
class MathThemeScope extends InheritedComponent {
  /// Provides [data] to [child].
  const MathThemeScope({
    required this.data,
    required super.child,
    super.key,
  });

  /// The math styling in effect below this scope.
  final MathTheme data;

  /// The math theme in effect, or [MathTheme.none] where no scope was
  /// installed — so a view built outside one renders math uncolorized rather
  /// than failing.
  static MathTheme of(BuildContext context) =>
      context.dependOnInheritedComponentOfExactType<MathThemeScope>()?.data ??
      MathTheme.none;

  @override
  bool updateShouldNotify(MathThemeScope oldComponent) =>
      data != oldComponent.data;
}
