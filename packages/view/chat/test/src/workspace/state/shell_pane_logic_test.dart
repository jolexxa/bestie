import 'dart:async';
import 'dart:convert';

import 'package:bestie_chat_view/src/workspace/state/shell_pane_cubit.dart';
import 'package:bestie_chat_view/src/workspace/state/shell_pane_input.dart';
import 'package:bestie_chat_view/src/workspace/state/shell_pane_output.dart';
import 'package:bestie_chat_view/src/workspace/state/shell_pane_state.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shell_repository/shell_repository.dart';
import 'package:terminal_screen/terminal_screen.dart';
import 'package:test/test.dart';
import 'package:vt_parser/vt_parser.dart';

class _MockSurface extends Mock implements TerminalSurface {}

Screen _screenWith(String input, {int scrollbackBytes = 0}) {
  final screen = Screen(rows: 4, cols: 8, scrollbackBytes: scrollbackBytes);
  VtParser(sink: screen).advance(utf8.encode(input));
  screen.snapshot();
  return screen;
}

void main() {
  setUpAll(() {
    registerFallbackValue(<int>[]);
  });

  late _MockSurface surface;
  late StreamController<void> changes;
  late ShellPaneLogic logic;

  /// Puts a screen behind the surface, as a spawn does.
  Screen spawn({String output = 'hi', int scrollbackBytes = 0}) {
    final screen = _screenWith(output, scrollbackBytes: scrollbackBytes);
    when(() => surface.screen).thenReturn(screen);
    when(() => surface.viewOffset).thenAnswer((_) => screen.viewOffset);
    when(() => surface.setViewOffset(any())).thenAnswer(
      (i) => screen.setViewOffset(i.positionalArguments.first as int),
    );
    return screen;
  }

  setUp(() {
    surface = _MockSurface();
    changes = StreamController<void>.broadcast();
    when(() => surface.changes).thenAnswer((_) => changes.stream);
    when(() => surface.screen).thenReturn(null);
    when(() => surface.exited).thenReturn(false);
    when(() => surface.viewOffset).thenReturn(0);
    when(() => surface.write(any())).thenReturn(null);
    when(
      () => surface.resize(
        rows: any(named: 'rows'),
        cols: any(named: 'cols'),
      ),
    ).thenReturn(null);
    logic = ShellPaneLogic(surface: surface);
  });

  tearDown(() async {
    logic.stop();
    await changes.close();
  });

  group('initial state', () {
    test('waits on a surface that has not put anything on screen', () {
      expect(logic.start(), isA<ShellPaneSpawning>());
    });

    // A pane mounted over an already-running shell — an agent's shell opened
    // in the details pane, say — gets no state change to tell it so.
    test('opens live on a surface that already spawned', () {
      spawn();
      final state = logic.start();
      expect(state, isA<ShellPaneLive>());
      expect(state.showCursor, isTrue);
    });

    test('opens exited on a shell whose transcript is all that is left', () {
      spawn();
      when(() => surface.exited).thenReturn(true);
      final state = logic.start();
      expect(state, isA<ShellPaneExited>());
      expect(state.showCursor, isFalse);
    });
  });

  group('following the surface', () {
    test('a spawn moves the pane off its placeholder', () {
      expect(logic.start(), isA<ShellPaneSpawning>());
      spawn();
      expect(logic.input(const SurfaceChanged()), isA<ShellPaneLive>());
    });

    // The very first chunk of output is how a pane learns it has a screen:
    // no lifecycle change announces it.
    test('a first paint alone moves the pane off its placeholder', () {
      expect(logic.start(), isA<ShellPaneSpawning>());
      spawn();
      expect(logic.input(const SurfaceChanged()), isA<ShellPaneLive>());
    });

    test('an exit drops the cursor but keeps the transcript', () {
      spawn();
      logic.start();
      when(() => surface.exited).thenReturn(true);
      final state = logic.input(const SurfaceChanged());
      expect(state, isA<ShellPaneExited>());
      expect((state as ShellPaneReady).screen, isNotNull);
    });

    test('a surface losing its screen falls back to the placeholder', () {
      spawn();
      logic.start();
      when(() => surface.screen).thenReturn(null);
      expect(logic.input(const SurfaceChanged()), isA<ShellPaneSpawning>());
    });

    test('repaints on every screen change', () {
      spawn();
      logic.start();
      final binding = logic.bind();
      var repaints = 0;
      binding.onOutput<PaneUpdated>((_) => repaints++);

      logic
        ..input(const SurfaceChanged())
        ..input(const SurfaceChanged());

      expect(repaints, 2);
      binding.dispose();
    });
  });

  group('viewport', () {
    test('scrolls up into history and back down', () {
      final screen = spawn(
        output: List.generate(20, (i) => 'row$i').join('\r\n'),
        scrollbackBytes: 40 * 4096,
      );
      logic
        ..start()
        ..input(const ScrollView(3));
      expect(screen.viewOffset, 3);

      logic.input(const ScrollView(-2));
      expect(screen.viewOffset, 1);
    });

    test('snaps back to the live region on FollowOutput', () {
      final screen = spawn(
        output: List.generate(20, (i) => 'row$i').join('\r\n'),
        scrollbackBytes: 40 * 4096,
      );
      logic
        ..start()
        ..input(const ScrollView(3));
      expect(screen.viewOffset, 3);

      logic.input(const FollowOutput());
      expect(screen.viewOffset, 0);
    });

    // Asking to scroll past what the scrollback holds clamps, and a viewport
    // that did not move is not worth a repaint.
    test('does not repaint when the offset clamps to where it already was', () {
      spawn();
      logic.start();
      final binding = logic.bind();
      var repaints = 0;
      binding.onOutput<PaneUpdated>((_) => repaints++);

      logic.input(const ScrollView(50));

      expect(repaints, 0);
      binding.dispose();
    });
  });

  group('commands reach the surface', () {
    test('writes decoded bytes to the child', () {
      spawn();
      logic
        ..start()
        ..input(const WriteToChild([0x61]));
      verify(() => surface.write([0x61])).called(1);
    });

    test('passes a new surface size along', () {
      spawn();
      logic
        ..start()
        ..input(const ResizeSurface(rows: 10, cols: 40));
      verify(() => surface.resize(rows: 10, cols: 40)).called(1);
    });
  });

  group('lifecycle', () {
    test('stops following the surface once stopped', () async {
      spawn();
      logic.start();
      final binding = logic.bind();
      var repaints = 0;
      binding.onOutput<PaneUpdated>((_) => repaints++);

      logic.stop();
      changes.add(null);
      await Future<void>.delayed(Duration.zero);

      expect(repaints, 0);
      binding.dispose();
    });
  });
}
