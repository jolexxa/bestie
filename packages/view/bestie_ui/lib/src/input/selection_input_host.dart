import 'package:intentions/intentions.dart';
import 'package:nocterm/nocterm.dart';

/// Per-event key handler. Returns `true` if the handler consumed the
/// event (caller should NOT fall through to its own handling).
typedef SelectionKeyHandler = bool Function(KeyboardEvent event);

/// Mutable handler slot owned by a [SelectionInputHost].
///
/// Descendants read this controller via [SelectionInputHost.of] and
/// register their own handler (typically a rich timeline item that
/// wants to claim keystrokes while it's the selected row). Ancestors
/// of the host (the chat page's outer `Focusable`, the chat input
/// row's `TextField.onKeyEvent`) call [tryHandle] before falling
/// through to their existing dispatch.
///
/// Binding is identity-checked: when [unbind] is called with an owner
/// that no longer matches the current binding (e.g. a new selectable
/// bound before the old one's `dispose` fired during a rebuild race),
/// it is a safe no-op rather than clobbering the new binding.
@model
class SelectionInputController {
  SelectionKeyHandler? _handler;
  Object? _owner;

  /// True when a handler is currently registered.
  bool get hasHandler => _handler != null;

  /// Routes [event] to the registered handler. Returns the handler's
  /// `true`/`false` decision, or `false` when no handler is bound.
  bool tryHandle(KeyboardEvent event) => _handler?.call(event) ?? false;

  /// Registers [handler] under [owner]. Replaces any prior binding.
  void bind(Object owner, SelectionKeyHandler handler) {
    _handler = handler;
    _owner = owner;
  }

  /// Releases the binding iff [owner] is the current holder. Race-safe.
  void unbind(Object owner) {
    if (identical(_owner, owner)) {
      _handler = null;
      _owner = null;
    }
  }
}

/// Mounts a single shared [SelectionInputController] into the subtree.
///
/// Place this above any rich timeline items that want to claim keys
/// when selected, but at or below the dispatch sites that consult the
/// controller (chat page `Focusable`, chat input row's `TextField`).
/// The controller reference is stable for the host's lifetime, so
/// `updateShouldNotify` always returns `false` — bind/unbind never
/// triggers a dependent rebuild cascade.
@view
class SelectionInputHost extends StatefulComponent {
  const SelectionInputHost({required this.child, super.key});

  final Component child;

  /// Returns the controller from the nearest enclosing host. When no
  /// host is mounted (e.g. an isolated view test), returns a detached
  /// controller whose [SelectionInputController.tryHandle] always
  /// returns `false` — so callers don't need to null-check.
  static SelectionInputController of(BuildContext context) {
    final scope = context
        .dependOnInheritedComponentOfExactType<_SelectionInputScope>();
    return scope?.controller ?? _detached;
  }

  static final SelectionInputController _detached = SelectionInputController();

  @override
  State<SelectionInputHost> createState() => _SelectionInputHostState();
}

class _SelectionInputHostState extends State<SelectionInputHost> {
  final SelectionInputController _controller = SelectionInputController();

  @override
  Component build(BuildContext context) =>
      _SelectionInputScope(controller: _controller, child: component.child);
}

class _SelectionInputScope extends InheritedComponent {
  const _SelectionInputScope({
    required this.controller,
    required super.child,
  });

  final SelectionInputController controller;

  @override
  bool updateShouldNotify(_SelectionInputScope oldComponent) => false;
}

/// Binds a key handler with the surrounding [SelectionInputHost]
/// while [selected] is true. Cleans up on deselect or dispose. Uses
/// `this` as the owner identity so the host's race-safe unbind
/// correctly ignores stale unbinds.
@view
class SelectableHandler extends StatefulComponent {
  const SelectableHandler({
    required this.selected,
    required this.onKey,
    required this.child,
    super.key,
  });

  final bool selected;
  final SelectionKeyHandler onKey;
  final Component child;

  @override
  State<SelectableHandler> createState() => _SelectableHandlerState();
}

class _SelectableHandlerState extends State<SelectableHandler> {
  SelectionInputController? _controller;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = SelectionInputHost.of(context);
    if (!identical(next, _controller)) {
      _controller?.unbind(this);
      _controller = next;
      if (component.selected) _controller!.bind(this, component.onKey);
    }
  }

  @override
  void didUpdateComponent(SelectableHandler old) {
    super.didUpdateComponent(old);
    if (component.selected) {
      _controller?.bind(this, component.onKey);
    } else if (old.selected) {
      _controller?.unbind(this);
    }
  }

  @override
  void dispose() {
    _controller?.unbind(this);
    super.dispose();
  }

  @override
  Component build(BuildContext context) => component.child;
}
