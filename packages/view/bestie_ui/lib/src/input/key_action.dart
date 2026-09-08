import 'package:intentions/intentions.dart';
import 'package:nocterm/nocterm.dart';

/// A declarative keyboard action that drives both keybinding dispatch
/// and footer label rendering from a single definition.
@model
class KeyAction {
  const KeyAction({
    required this.label,
    required this.key,
    required this.onActivate,
    this.ctrl = false,
    this.shift = false,
    this.alt = false,
    this.visible = true,
    this.enabled = true,
    this.index,
    this.footerOverride,
  });

  /// Human-readable action name (e.g., 'Send', 'Reset', 'Think: ON').
  final String label;

  /// The logical key that triggers this action.
  final LogicalKey key;

  /// Callback invoked when the action is triggered.
  final VoidCallback onActivate;

  /// Whether the Ctrl modifier is required.
  final bool ctrl;

  /// Whether the Shift modifier is required.
  final bool shift;

  /// Whether the Alt modifier is required.
  final bool alt;

  /// Whether to show this action in the footer.
  final bool visible;

  /// Whether the keybinding is currently active.
  final bool enabled;

  /// Optional index that can be used to order actions in the footer.
  final int? index;

  /// When non-null, replaces the auto-generated footer label entirely.
  /// Useful for combined indicators like `[PgUp/PgDn] Page`.
  final String? footerOverride;

  /// Identity of this action's keybinding, used to dedup colliding bindings
  /// across nested action scopes (innermost-wins).
  String get signature {
    final parts = <String>[];
    if (ctrl) parts.add('Ctrl');
    if (shift) parts.add('Shift');
    if (alt) parts.add('Alt');
    parts.add(key.debugName);
    return parts.join('+');
  }

  /// Number of required modifier keys. Used as a specificity score so that
  /// more-modifier bindings (e.g. `Shift+Tab`) take precedence over
  /// less-modifier bindings (e.g. `Tab`) when both are present in a merged
  /// scope.
  int get modifierCount => (ctrl ? 1 : 0) + (shift ? 1 : 0) + (alt ? 1 : 0);

  /// Footer label, e.g., `[Ctrl+R] Reset`.
  String get footerLabel {
    if (footerOverride != null) return footerOverride!;
    final parts = <String>[];
    if (ctrl) parts.add('Ctrl');
    if (shift) parts.add('Shift');
    if (alt) parts.add('Alt');
    parts.add(_keyDisplayName);
    return '[${parts.join('+')}] $label';
  }

  /// Returns `true` if [event] matches this action and was handled.
  ///
  /// Modifier matching is strict: a binding with `ctrl: false` will only
  /// match events where Ctrl is *not* held. This means `Tab` does not
  /// silently swallow `Shift+Tab`, `Ctrl+Tab`, etc.
  bool tryHandle(KeyboardEvent event) {
    if (!enabled) return false;
    final matched = event.matches(
      key,
      ctrl: ctrl,
      shift: shift,
      alt: alt,
    );
    if (!matched) return false;
    onActivate();
    return true;
  }

  /// Dispatches [event] through [actions], returning `true` if any handled it.
  static bool handleEvent(
    KeyboardEvent event,
    List<KeyAction> actions,
  ) {
    for (final action in actions) {
      if (action.tryHandle(event)) return true;
    }
    return false;
  }

  static const _displayNames = <String, String>{
    'enter': 'Enter',
    'tab': 'Tab',
    'backspace': 'Bksp',
    'escape': 'Esc',
    'delete': 'Del',
    'space': 'Space',
    'arrowUp': 'Up',
    'arrowDown': 'Down',
    'arrowLeft': 'Left',
    'arrowRight': 'Right',
    'pageUp': 'PgUp',
    'pageDown': 'PgDn',
    'home': 'Home',
    'end': 'End',
    'insert': 'Ins',
  };

  String get _keyDisplayName {
    final name = key.debugName;
    final mapped = _displayNames[name];
    if (mapped != null) return mapped;
    // Letter keys: 'keyC' -> 'C'
    if (name.startsWith('key') && name.length == 4) return name[3];
    // Digit keys: 'digit5' -> '5'
    if (name.startsWith('digit') && name.length == 6) return name[5];
    // Function keys: 'f1' -> 'F1'
    if (name.startsWith('f') && name.length <= 3) return name.toUpperCase();
    return name;
  }
}
