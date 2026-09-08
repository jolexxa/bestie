import 'package:intentions/intentions.dart';
import 'package:nocterm/nocterm.dart';

/// Whether decorative motion is on. The app sets it from config; anything
/// that animates for looks alone reads it and holds still when it is off.
@view
class ThemeEffects extends InheritedComponent {
  const ThemeEffects({required this.enabled, required super.child, super.key});

  final bool enabled;

  /// Defaults to on when no scope is above.
  static bool of(BuildContext context) =>
      context.dependOnInheritedComponentOfExactType<ThemeEffects>()?.enabled ??
      true;

  @override
  bool updateShouldNotify(ThemeEffects oldComponent) =>
      enabled != oldComponent.enabled;
}
