import 'dart:math';

import 'package:bestie_chat_view/src/view/components/mascot_icon.dart';
import 'package:bestie_mascot_use_case/bestie_mascot_use_case.dart';
import 'package:bestie_ui/bestie_ui.dart';
import 'package:nocterm/nocterm.dart';
import 'package:test/test.dart';

void main() {
  group('MascotIcons', () {
    final families = {
      for (final mascot in Mascot.values) mascot: mascotIconsFor(mascot),
    };

    test('every mascot has an icon family', () {
      expect(families.values, everyElement(isNotNull));
    });

    test('the still pose is the first idle frame', () {
      for (final icons in families.values) {
        expect(icons.still, same(icons.idleFrames.first));
      }
    });

    test('every frame renders in the same box so the corner never shifts', () {
      for (final MapEntry(key: mascot, value: icons) in families.entries) {
        final frames = [...icons.idleFrames, ...icons.talkingFrames];
        for (final frame in frames) {
          expect(
            frame,
            hasLength(MascotIcons.frameHeight),
            reason: '${mascot.id} frame height',
          );
          final widest = frame.map((line) => line.length).reduce(max);
          expect(
            widest,
            MascotIcons.frameWidth,
            reason: '${mascot.id} frame ${frame.join('\n')}',
          );
        }
      }
    });

    test('idle animation actually animates', () {
      for (final icons in families.values) {
        expect(icons.idleFrames.toSet().length, greaterThan(1));
        expect(icons.talkingFrames.toSet().length, greaterThan(1));
      }
    });
  });

  group('MascotBubbles', () {
    test('bubble frames match the icon height and bubble width', () {
      final frames = [
        MascotBubbles.thought,
        MascotBubbles.blank,
        ...MascotBubbles.thoughtFrames,
        ...MascotBubbles.speakingFrames,
      ];
      for (final frame in frames) {
        expect(frame, hasLength(MascotIcons.frameHeight));
        for (final line in frame) {
          expect(line.length, MascotBubbles.width);
        }
      }
    });
  });

  group('MascotIconStatic', () {
    const backdrop = Color(0x336633);

    test('colors its glyphs and leaves every space see-through', () async {
      await testNocterm('mascot fill', size: const Size(20, 7), (tester) async {
        await tester.pumpComponent(
          AppTheme(
            data: appThemeDefault,
            child: TuiTheme(
              data: appThemeDefault,
              child: Stack(
                children: [
                  Positioned.fill(child: const Container(color: backdrop)),
                  const MascotIconStatic(icons: MascotIcons.cow),
                ],
              ),
            ),
          ),
        );
        // The cow's still pose opens with two spaces, then ")__(" on the
        // first art row, which sits under the icon's one-row top padding.
        final glyph = tester.terminalState.getCellAt(2, 1);
        expect(glyph?.char, ')');
        expect(glyph?.style.color, appThemeDefault.primary);
        expect(glyph?.style.backgroundColor, backdrop);
        final gap = tester.terminalState.getCellAt(0, 1);
        expect(gap?.style.backgroundColor, backdrop);
        // Inside the face, "( oo )" on the second art row, the space between
        // the paren and the eyes is plain art and shows the ground too.
        final face = tester.terminalState.getCellAt(2, 2);
        expect(face?.char, ' ');
        expect(face?.style.backgroundColor, backdrop);
      });
    });

    test('splits a line into glyph runs and transparent gaps', () {
      const glyph = TextStyle(color: Color(0xFFFFFF));
      final spans = mascotSpans('  )__(  ', glyph: glyph);
      expect(spans.map((span) => span.text), ['  ', ')__(', '  ']);
      expect(spans.map((span) => span.style), [null, glyph, null]);
    });
  });
}
