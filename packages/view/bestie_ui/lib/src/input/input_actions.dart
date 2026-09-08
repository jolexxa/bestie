import 'package:bestie_ui/src/input/key_action.dart';
import 'package:intentions/intentions.dart';
import 'package:nocterm/nocterm.dart';

/// Provides a set of [KeyAction]s to descendants and merges them with any
/// ancestor [InputActions] scope, innermost-first.
///
/// Both keyboard dispatch and footer rendering should pull from
/// [of] / [dispatch] so that overlays, screens, and root-level
/// globals all compose without any one layer needing to know about the
/// others. Bindings with the same `(key + modifiers)` signature shadow
/// outer ones — an overlay's `Esc=Cancel` correctly overrides a page's
/// `Esc=Stop` simply by being closer in the tree.
@view
class InputActions extends StatelessComponent {
  const InputActions({
    required this.actions,
    required this.child,
    super.key,
  });

  /// The actions contributed by this scope.
  final List<KeyAction> actions;

  /// The subtree these actions apply to.
  final Component child;

  /// Returns the merged ancestor-chain action list visible to [context]
  /// in **dispatch order** — sorted by modifier specificity so that
  /// `Shift+Tab` is visited before bare `Tab`. Used by dispatch and by
  /// any caller that doesn't care about declaration order.
  ///
  /// Returns an empty list if no [InputActions] ancestor exists.
  static List<KeyAction> of(BuildContext context) =>
      _InputActionsScope.maybeOf(context)?.dispatchOrder ?? const <KeyAction>[];

  /// Returns the merged ancestor-chain action list visible to [context]
  /// in **declaration order** — innermost scope's actions first,
  /// without the modifier-specificity sort. Used by footer rendering
  /// so that group columns appear in scope-declaration order: an
  /// overlay's group leftmost, the page's groups middle, global
  /// groups rightmost — independent of which scope's bindings happen
  /// to use more modifiers.
  static List<KeyAction> renderOrderOf(BuildContext context) =>
      _InputActionsScope.maybeOf(context)?.renderOrder ?? const <KeyAction>[];

  /// Dispatches [event] through the merged action list visible to
  /// [context]. Returns `true` if any action handled it.
  static bool dispatch(BuildContext context, KeyboardEvent event) =>
      KeyAction.handleEvent(event, of(context));

  @override
  Component build(BuildContext context) {
    final parent = _InputActionsScope.maybeOf(context);
    final concat = _concat(
      actions,
      parent?.renderOrder ?? const <KeyAction>[],
    );
    final sorted = _sortByModifier(concat);
    return _InputActionsScope(
      renderOrder: concat,
      dispatchOrder: sorted,
      child: child,
    );
  }

  /// Concatenates [inner] in front of [outer], dropping any [outer]
  /// entry that collides with an [inner] one by [KeyAction.signature].
  /// Preserves declaration order — inner scope's actions first.
  static List<KeyAction> _concat(
    List<KeyAction> inner,
    List<KeyAction> outer,
  ) {
    if (outer.isEmpty) return List<KeyAction>.unmodifiable(inner);
    final seen = <String>{for (final a in inner) a.signature};
    return List<KeyAction>.unmodifiable([
      ...inner,
      for (final a in outer)
        if (seen.add(a.signature)) a,
    ]);
  }

  /// Stable-sorts [concat] by [KeyAction.modifierCount] descending so
  /// more-specific bindings (e.g. `Shift+Tab`) are visited before
  /// less-specific ones during dispatch. Strict modifier matching
  /// already prevents the bug, but the sort keeps things robust
  /// against any future binding that intentionally uses loose
  /// matching.
  static List<KeyAction> _sortByModifier(List<KeyAction> concat) {
    final sorted = [...concat]
      ..sort((a, b) => b.modifierCount.compareTo(a.modifierCount));
    return List<KeyAction>.unmodifiable(sorted);
  }
}

class _InputActionsScope extends InheritedComponent {
  const _InputActionsScope({
    required this.renderOrder,
    required this.dispatchOrder,
    required super.child,
  });

  /// Declaration order: innermost scope's actions first, no
  /// modifier-specificity sort. Footer rendering reads this so group
  /// columns appear in scope order.
  final List<KeyAction> renderOrder;

  /// Same actions, sorted by modifier specificity descending. Dispatch
  /// walks this so that `Shift+Tab` matches before bare `Tab`.
  final List<KeyAction> dispatchOrder;

  static _InputActionsScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedComponentOfExactType<_InputActionsScope>();

  @override
  bool updateShouldNotify(_InputActionsScope oldComponent) =>
      !identical(renderOrder, oldComponent.renderOrder) ||
      !identical(dispatchOrder, oldComponent.dispatchOrder);
}
