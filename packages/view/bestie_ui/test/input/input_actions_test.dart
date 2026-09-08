import 'package:bestie_ui/bestie_ui.dart';
import 'package:nocterm/nocterm.dart';
import 'package:test/test.dart' hide isEmpty;

/// Captures the merged action list and the build-context handed to a child
/// at first build, so tests can drive [InputActions.dispatch] against the
/// same context a real focused widget would receive.
class _Capture extends StatelessComponent {
  const _Capture({required this.onBuild});
  final void Function(BuildContext context, List<KeyAction> merged) onBuild;

  @override
  Component build(BuildContext context) {
    onBuild(context, InputActions.of(context));
    return const SizedBox();
  }
}

KeyAction _action(
  String label, {
  required LogicalKey key,
  required VoidCallback onActivate,
  bool ctrl = false,
  bool shift = false,
  bool alt = false,
}) => KeyAction(
  label: label,
  key: key,
  ctrl: ctrl,
  shift: shift,
  alt: alt,
  onActivate: onActivate,
);

KeyboardEvent _press(
  LogicalKey key, {
  bool ctrl = false,
  bool shift = false,
  bool alt = false,
}) => KeyboardEvent(
  logicalKey: key,
  modifiers: ModifierKeys(ctrl: ctrl, shift: shift, alt: alt),
);

/// Pumps [tree] with a [_Capture] spliced as the deepest leaf, then returns
/// the captured (context, merged) pair.
Future<({BuildContext context, List<KeyAction> merged})> _capture(
  NoctermTester tester,
  Component tree,
) async {
  late BuildContext capturedContext;
  late List<KeyAction> capturedMerged;
  final captor = _Capture(
    onBuild: (ctx, merged) {
      capturedContext = ctx;
      capturedMerged = merged;
    },
  );
  await tester.pumpComponent(_injectChild(tree, captor));
  return (context: capturedContext, merged: capturedMerged);
}

/// Replaces the deepest [InputActions]'s child with [leaf]. Tests build a
/// scope tree and we splice the captor in as the leaf so it sees the full
/// merged ancestor chain.
Component _injectChild(Component tree, Component leaf) {
  if (tree is InputActions) {
    return InputActions(
      actions: tree.actions,
      child: _injectChild(tree.child, leaf),
    );
  }
  return leaf;
}

void main() {
  group('InputActions.mergedOf', () {
    test('returns empty list when no scope ancestor exists', () async {
      await testNocterm('mergedOf empty', (tester) async {
        final result = await _capture(tester, const SizedBox());
        expect(result.merged, hasLength(0));
      });
    });

    test('returns scope actions when only one scope ancestor exists', () async {
      await testNocterm('mergedOf single scope', (tester) async {
        final result = await _capture(
          tester,
          InputActions(
            actions: [
              _action('Send', key: LogicalKey.enter, onActivate: () {}),
            ],
            child: const SizedBox(),
          ),
        );
        expect(result.merged, hasLength(1));
        expect(result.merged.single.label, 'Send');
      });
    });

    test('within same modifier count, inner comes before outer', () async {
      await testNocterm('mergedOf same-mods inner first', (tester) async {
        final result = await _capture(
          tester,
          InputActions(
            actions: [
              _action('Cancel', key: LogicalKey.escape, onActivate: () {}),
            ],
            child: InputActions(
              actions: [
                _action('Send', key: LogicalKey.enter, onActivate: () {}),
              ],
              child: const SizedBox(),
            ),
          ),
        );
        expect(
          result.merged.map((a) => a.label).toList(),
          ['Send', 'Cancel'],
        );
      });
    });

    test('sorts more-specific bindings before less-specific ones', () async {
      await testNocterm('mergedOf specificity', (tester) async {
        final result = await _capture(
          tester,
          InputActions(
            actions: [
              _action(
                'Next',
                key: LogicalKey.tab,
                shift: true,
                onActivate: () {},
              ),
            ],
            child: InputActions(
              actions: [
                _action('Sort', key: LogicalKey.tab, onActivate: () {}),
              ],
              child: const SizedBox(),
            ),
          ),
        );
        // Even though `Sort` is the inner binding, `Next` (Shift+Tab) sorts
        // first because it carries more modifiers.
        expect(
          result.merged.map((a) => a.label).toList(),
          ['Next', 'Sort'],
        );
      });
    });

    test('inner shadows outer when (key + modifiers) collide', () async {
      await testNocterm('mergedOf collision', (tester) async {
        final result = await _capture(
          tester,
          InputActions(
            actions: [
              _action('Stop', key: LogicalKey.escape, onActivate: () {}),
            ],
            child: InputActions(
              actions: [
                _action('Cancel', key: LogicalKey.escape, onActivate: () {}),
              ],
              child: const SizedBox(),
            ),
          ),
        );
        expect(result.merged, hasLength(1));
        expect(result.merged.single.label, 'Cancel');
      });
    });

    test('modifier-different bindings on same key are kept distinct', () async {
      await testNocterm('mergedOf modifiers distinct', (tester) async {
        final result = await _capture(
          tester,
          InputActions(
            actions: [
              _action('Tab next', key: LogicalKey.tab, onActivate: () {}),
            ],
            child: InputActions(
              actions: [
                _action(
                  'Tab prev',
                  key: LogicalKey.tab,
                  shift: true,
                  onActivate: () {},
                ),
              ],
              child: const SizedBox(),
            ),
          ),
        );
        expect(
          result.merged.map((a) => a.label).toSet(),
          {'Tab next', 'Tab prev'},
        );
      });
    });
  });

  group('InputActions.dispatch', () {
    test('returns false when no action matches', () async {
      await testNocterm('dispatch no match', (tester) async {
        final result = await _capture(
          tester,
          InputActions(
            actions: [
              _action('Send', key: LogicalKey.enter, onActivate: () {}),
            ],
            child: const SizedBox(),
          ),
        );
        final handled = InputActions.dispatch(
          result.context,
          _press(LogicalKey.escape),
        );
        expect(handled, isFalse);
      });
    });

    test('fires inner handler when inner shadows outer', () async {
      await testNocterm('dispatch inner wins', (tester) async {
        var outerFired = 0;
        var innerFired = 0;
        final result = await _capture(
          tester,
          InputActions(
            actions: [
              _action(
                'Stop',
                key: LogicalKey.escape,
                onActivate: () => outerFired++,
              ),
            ],
            child: InputActions(
              actions: [
                _action(
                  'Cancel',
                  key: LogicalKey.escape,
                  onActivate: () => innerFired++,
                ),
              ],
              child: const SizedBox(),
            ),
          ),
        );
        final handled = InputActions.dispatch(
          result.context,
          _press(LogicalKey.escape),
        );
        expect(handled, isTrue);
        expect(innerFired, 1);
        expect(outerFired, 0);
      });
    });

    test('strict modifiers: Tab binding does not match Shift+Tab', () async {
      await testNocterm('dispatch strict mods', (tester) async {
        var tabFired = 0;
        final result = await _capture(
          tester,
          InputActions(
            actions: [
              _action(
                'Sort',
                key: LogicalKey.tab,
                onActivate: () => tabFired++,
              ),
            ],
            child: const SizedBox(),
          ),
        );
        final handled = InputActions.dispatch(
          result.context,
          _press(LogicalKey.tab, shift: true),
        );
        expect(handled, isFalse);
        expect(tabFired, 0);
      });
    });

    test(
      'Shift+Tab fires Next even when Tab is bound (browse repro)',
      () async {
        // Regression: in browse, base actions bind plain `Tab` (Sort/Backend)
        // and root binds `Shift+Tab` (Next mode). Pressing Shift+Tab must
        // fire Next, not Sort.
        await testNocterm('dispatch shift+tab over tab', (tester) async {
          var nextFired = 0;
          var sortFired = 0;
          final result = await _capture(
            tester,
            InputActions(
              actions: [
                _action(
                  'Next',
                  key: LogicalKey.tab,
                  shift: true,
                  onActivate: () => nextFired++,
                ),
              ],
              child: InputActions(
                actions: [
                  _action(
                    'Sort',
                    key: LogicalKey.tab,
                    onActivate: () => sortFired++,
                  ),
                ],
                child: const SizedBox(),
              ),
            ),
          );
          final handled = InputActions.dispatch(
            result.context,
            _press(LogicalKey.tab, shift: true),
          );
          expect(handled, isTrue);
          expect(nextFired, 1);
          expect(sortFired, 0);
        });
      },
    );

    test('fires outer handler when inner does not bind the key', () async {
      await testNocterm('dispatch outer fallback', (tester) async {
        var outerFired = 0;
        final result = await _capture(
          tester,
          InputActions(
            actions: [
              _action(
                'Quit',
                key: LogicalKey.keyC,
                ctrl: true,
                onActivate: () => outerFired++,
              ),
            ],
            child: InputActions(
              actions: [
                _action('Send', key: LogicalKey.enter, onActivate: () {}),
              ],
              child: const SizedBox(),
            ),
          ),
        );
        final handled = InputActions.dispatch(
          result.context,
          _press(LogicalKey.keyC, ctrl: true),
        );
        expect(handled, isTrue);
        expect(outerFired, 1);
      });
    });
  });

  group('InputActions.renderOrderOf', () {
    test(
      'nested scopes list innermost-first',
      () async {
        await testNocterm('nested groups preserved', (tester) async {
          final result = await _capture(
            tester,
            InputActions(
              actions: [
                _action(
                  'Outer-A',
                  key: LogicalKey.keyA,
                  onActivate: () {},
                ),
              ],
              child: InputActions(
                actions: [
                  _action(
                    'Inner-B',
                    key: LogicalKey.keyB,
                    onActivate: () {},
                  ),
                ],
                child: const SizedBox(),
              ),
            ),
          );
          expect(result.merged.map((a) => a.label).toList(), [
            'Inner-B',
            'Outer-A',
          ]);
        });
      },
    );

    test(
      'render order keeps inner-first when outer has more modifiers than inner '
      '(global App scope regression)',
      () async {
        // Regression: globals (Ctrl+C/Quit, Ctrl+O/Config, Shift+Tab/Next)
        // all have mod=1, but page bindings on browse/models/etc are mostly
        // bare arrows/Enter (mod=0). The dispatch-time sort would hoist
        // App in front of the page groups, making App render as the first
        // column. Footer should bucket from the *unsorted* concat order
        // (innermost first) so App stays last.
        await testNocterm('render keeps inner-first', (tester) async {
          await tester.pumpComponent(
            InputActions(
              actions: [
                _action(
                  'Quit',
                  key: LogicalKey.keyC,
                  ctrl: true,
                  onActivate: () {},
                ),
              ],
              child: InputActions(
                actions: [
                  _action(
                    'Nav',
                    key: LogicalKey.arrowUp,
                    onActivate: () {},
                  ),
                  _action(
                    'Install',
                    key: LogicalKey.enter,
                    onActivate: () {},
                  ),
                ],
                child: _Capture(
                  onBuild: (ctx, _) {
                    final render = InputActions.renderOrderOf(ctx);
                    final dispatch = InputActions.of(ctx);
                    // Render: inner first → Nav, Install, Quit.
                    expect(
                      render.map((a) => a.label).toList(),
                      ['Nav', 'Install', 'Quit'],
                    );
                    // Dispatch: mod=1 (Quit) sorted ahead of mod=0
                    // (Nav, Install) — current sort behavior.
                    expect(
                      dispatch.map((a) => a.label).toList(),
                      ['Quit', 'Nav', 'Install'],
                    );
                  },
                ),
              ),
            ),
          );
        });
      },
    );

    test('inner scope shadows an outer binding with the same key', () async {
      await testNocterm('inner shadows outer', (tester) async {
        var outerFired = 0;
        var innerFired = 0;
        final result = await _capture(
          tester,
          InputActions(
            actions: [
              _action(
                'Stop',
                key: LogicalKey.escape,
                onActivate: () => outerFired++,
              ),
            ],
            child: InputActions(
              actions: [
                _action(
                  'Cancel',
                  key: LogicalKey.escape,
                  onActivate: () => innerFired++,
                ),
              ],
              child: const SizedBox(),
            ),
          ),
        );
        InputActions.dispatch(result.context, _press(LogicalKey.escape));
        expect(innerFired, 1);
        expect(outerFired, 0);
      });
    });
  });

  group('KeyAction.signature', () {
    test('distinct for different modifier sets', () {
      final plain = _action(
        'A',
        key: LogicalKey.tab,
        onActivate: () {},
      ).signature;
      final shifted = _action(
        'B',
        key: LogicalKey.tab,
        shift: true,
        onActivate: () {},
      ).signature;
      final ctrled = _action(
        'C',
        key: LogicalKey.tab,
        ctrl: true,
        onActivate: () {},
      ).signature;
      expect({plain, shifted, ctrled}, hasLength(3));
    });

    test('matches when key + modifiers match', () {
      final a = _action('A', key: LogicalKey.escape, onActivate: () {});
      final b = _action('B', key: LogicalKey.escape, onActivate: () {});
      expect(a.signature, b.signature);
    });
  });
}
