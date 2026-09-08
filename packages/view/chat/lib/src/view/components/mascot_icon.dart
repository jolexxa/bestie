// Ascii art :P
// ignore_for_file: unnecessary_raw_strings

import 'dart:async';

import 'package:bestie_mascot_use_case/bestie_mascot_use_case.dart';
import 'package:bestie_ui/bestie_ui.dart';
import 'package:intentions/intentions.dart';
import 'package:nocterm/nocterm.dart';

/// One mascot's complete set of mascot animation frames.
@model
final class MascotIcons {
  const MascotIcons({required this.idleFrames, required this.talkingFrames});

  /// The width every frame renders at — each frame's widest line.
  static const int frameWidth = 16;

  /// The number of lines in every frame.
  static const int frameHeight = 5;

  /// Frames cycled while thinking; the first frame is the resting pose.
  final List<List<String>> idleFrames;

  /// Frames cycled while the response streams in.
  final List<List<String>> talkingFrames;

  /// The resting pose shown when nothing is happening.
  List<String> get still => idleFrames.first;

  static const MascotIcons cow = MascotIcons(
    idleFrames: [
      _cowRest,
      _cowTailIn,
      _cowRest,
      _cowTailOut,
      _cowTailUp,
      _cowTailOut,
      _cowRest,
      _cowRest,
      _cowBlink,
      _cowRest,
    ],
    talkingFrames: [_cowTalk1, _cowTalk2, _cowTalk3, _cowTalk4],
  );

  static const MascotIcons dino = MascotIcons(
    idleFrames: [
      _dinoRest,
      _dinoTailLift,
      _dinoRest,
      _dinoTailLift,
      _dinoTailUp,
      _dinoTailLift,
      _dinoRest,
      _dinoRest,
      _dinoBlink,
      _dinoRest,
    ],
    talkingFrames: [_dinoTalk1, _dinoTalk2, _dinoTalk3, _dinoTalk4],
  );
}

/// The icon family for the selected [mascot].
MascotIcons mascotIconsFor(Mascot mascot) => switch (mascot) {
  Mascot.cow => MascotIcons.cow,
  Mascot.dino => MascotIcons.dino,
};

const List<String> _cowRest = <String>[
  r'  )__(          ',
  r' ( oo )  __     ',
  r'  (__) \-- -\   ',
  r'    | ____ | |  ',
  r'    |_|  |_| *  ',
];

const List<String> _cowTailIn = <String>[
  r'  )__(          ',
  r' ( oo )  __     ',
  r'  (__) \-- -\   ',
  r'    | ____ | |  ',
  r'    |_|  |_|*   ',
];

const List<String> _cowTailOut = <String>[
  r'  )__(          ',
  r' ( oo )  __     ',
  r'  (__) \-- -\   ',
  r'    | ____ | |  ',
  r'    |_|  |_|  * ',
];

const List<String> _cowTailUp = <String>[
  r'  )__(          ',
  r' ( oo )  __     ',
  r'  (__) \-- -\   ',
  r'    | ____ | \* ',
  r'    |_|  |_|    ',
];

const List<String> _cowBlink = <String>[
  r'  )__(          ',
  r' ( -- )  __     ',
  r'  (__) \-- -\   ',
  r'    | ____ | |  ',
  r'    |_|  |_| *  ',
];

const List<String> _cowTalk1 = <String>[
  r'  )__(          ',
  r' (oo  )  __     ',
  r' (__)  \-- -\   ',
  r'    | ____ | |  ',
  r'    |_|  |_| *  ',
];

const List<String> _cowTalk2 = <String>[
  r'  )__(          ',
  r' (oo  )  __     ',
  r' (*.)  \-- -\   ',
  r'    | ____ | |  ',
  r'    |_|  |_| *  ',
];

const List<String> _cowTalk3 = <String>[
  r'  )__(          ',
  r' (oo  )  __     ',
  r' (^ )  \-- -\   ',
  r'    | ____ | |  ',
  r'    |_|  |_| *  ',
];

const List<String> _cowTalk4 = <String>[
  r'  )__(          ',
  r' (oo  )  __     ',
  r' (.*)  \-- -\   ',
  r'    | ____ | |  ',
  r'    |_|  |_| *  ',
];

const List<String> _dinoRest = <String>[
  r'  ___           ',
  r' (__.\          ',
  r'    \ \^^.__    ',
  r'    (   __  )_  ',
  r'     |,|  |_| \_',
];

const List<String> _dinoTailLift = <String>[
  r'  ___           ',
  r' (__.\          ',
  r'    \ \^^.__    ',
  r'    (   __  )-__',
  r'     |,|  |_|   ',
];

const List<String> _dinoTailUp = <String>[
  r'  ___           ',
  r' (__.\          ',
  r'    \ \^^.__   .',
  r'    (   __  )_/ ',
  r'     |,|  |_|   ',
];

const List<String> _dinoBlink = <String>[
  r'  ___           ',
  r' (__*\          ',
  r'    \ \^^.__    ',
  r'    (   __  )_  ',
  r'     |,|  |_| \_',
];

const List<String> _dinoTalk1 = <String>[
  r' ___            ',
  r'(__.\`          ',
  r'    \ \^^.__    ',
  r'    (   __  )_  ',
  r'     |,|  |_| \_',
];

const List<String> _dinoTalk2 = <String>[
  r' ___            ',
  r'(*_.\`          ',
  r'    \ \^^.__    ',
  r'    (   __  )_  ',
  r'     |,|  |_| \_',
];

const List<String> _dinoTalk3 = <String>[
  r'  ___           ',
  r' (^_.\          ',
  r'    \ \^^.__    ',
  r'    (   __  )_  ',
  r'     |,|  |_| \_',
];

const List<String> _dinoTalk4 = <String>[
  r'  ___           ',
  r' (m_.\          ',
  r'    \ \^^.__    ',
  r'    (   __  )_  ',
  r'     |,|  |_| \_',
];

/// Bubble trails shared by every mascot.
@model
abstract final class MascotBubbles {
  /// The width every bubble line is padded to.
  static const int width = 7;

  static const List<String> thought = <String>[
    r'     o ',
    r'   o   ',
    r'     o ',
    r'       ',
    r'       ',
  ];

  static const List<String> blank = <String>[
    r'       ',
    r'       ',
    r'       ',
    r'       ',
    r'       ',
  ];

  static const List<List<String>> thoughtFrames = <List<String>>[
    <String>[
      r'       ',
      r'       ',
      r'     o ',
      r'       ',
      r'       ',
    ],
    <String>[
      r'       ',
      r'   o   ',
      r'       ',
      r'       ',
      r'       ',
    ],
    <String>[
      r'     o ',
      r'       ',
      r'       ',
      r'       ',
      r'       ',
    ],
    <String>[
      r'    .  ',
      r'       ',
      r'       ',
      r'       ',
      r'       ',
    ],
    blank,
  ];

  static const List<List<String>> speakingFrames = <List<String>>[
    <String>[
      r'       ',
      r'       ',
      r'      =',
      r'       ',
      r'       ',
    ],
    <String>[
      r'       ',
      r'    \  ',
      r'       ',
      r'    /  ',
      r'       ',
    ],
    <String>[
      r'       ',
      r'   .   ',
      r'       ',
      r'   .   ',
      r'       ',
    ],
    blank,
    blank,
  ];
}

/// A mascot's resting pose (not animated).
@view
class MascotIconStatic extends StatelessComponent {
  const MascotIconStatic({required this.icons, super.key});

  final MascotIcons icons;

  @override
  Component build(BuildContext context) {
    return _AsciiFrame(
      frame: icons.still,
      padding: const EdgeInsets.only(top: 1, right: 1),
    );
  }
}

/// An animated ASCII mascot that cycles expressions while generating.
@view
class MascotIconAnimated extends StatelessComponent {
  const MascotIconAnimated({required this.icons, super.key});

  final MascotIcons icons;

  @override
  Component build(BuildContext context) {
    return _AnimatedAsciiFrames(
      frames: icons.idleFrames,
      interval: const Duration(milliseconds: 400),
      padding: const EdgeInsets.only(top: 1, right: 1),
    );
  }
}

/// An animated ASCII mascot that chats along with the streaming response.
@view
class MascotIconTalkingAnimated extends StatelessComponent {
  const MascotIconTalkingAnimated({required this.icons, super.key});

  final MascotIcons icons;

  @override
  Component build(BuildContext context) {
    return _AnimatedAsciiFrames(
      frames: icons.talkingFrames,
      interval: const Duration(milliseconds: 400),
      padding: const EdgeInsets.only(top: 1, right: 1),
    );
  }
}

/// One line of ASCII art as runs: drawn glyphs carry [glyph], spaces stay
/// transparent so whatever is behind the art shows through.
List<TextSpan> mascotSpans(String line, {required TextStyle glyph}) {
  final spans = <TextSpan>[];
  final run = StringBuffer();
  var runIsGlyph = false;
  void flush() {
    if (run.isEmpty) return;
    spans.add(TextSpan(text: run.toString(), style: runIsGlyph ? glyph : null));
    run.clear();
  }

  for (final char in line.split('')) {
    final isGlyph = char != ' ';
    if (isGlyph != runIsGlyph) {
      flush();
      runIsGlyph = isGlyph;
    }
    run.write(char);
  }
  flush();
  return spans;
}

class _AsciiFrame extends StatelessComponent {
  const _AsciiFrame({required this.frame, required this.padding});

  final List<String> frame;
  final EdgeInsets padding;

  @override
  Component build(BuildContext context) {
    final glyph = TextStyle(color: AppTheme.of(context).primary);
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in frame)
            RichText(
              softWrap: false,
              text: TextSpan(children: mascotSpans(line, glyph: glyph)),
            ),
        ],
      ),
    );
  }
}

class _AnimatedAsciiFrames extends StatefulComponent {
  const _AnimatedAsciiFrames({
    required this.frames,
    required this.interval,
    required this.padding,
  });

  final List<List<String>> frames;
  final Duration interval;
  final EdgeInsets padding;

  @override
  State<_AnimatedAsciiFrames> createState() => _AnimatedAsciiFramesState();
}

class _AnimatedAsciiFramesState extends State<_AnimatedAsciiFrames> {
  Timer? _timer;
  int _index = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(component.interval, (_) {
      if (!mounted) return;
      setState(() {
        final length = component.frames.length;
        _index = length == 0 ? 0 : (_index + 1) % length;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Component build(BuildContext context) {
    final frames = component.frames;
    final frame = frames.isEmpty
        ? MascotBubbles.blank
        : frames[_index % frames.length];
    return _AsciiFrame(
      frame: frame,
      padding: component.padding,
    );
  }
}

/// An empty bubble trail that holds the slot open, so the mascot's column
/// keeps one width whether or not it has anything to say.
@view
class MascotBubblesBlank extends StatelessComponent {
  const MascotBubblesBlank({super.key});

  @override
  Component build(BuildContext context) {
    return const _AsciiFrame(
      frame: MascotBubbles.blank,
      padding: EdgeInsets.only(right: 1),
    );
  }
}

/// A small trail of thought bubbles that lead into the mascot.
@view
class MascotThoughtBubbles extends StatelessComponent {
  const MascotThoughtBubbles({super.key});

  @override
  Component build(BuildContext context) {
    return const _AsciiFrame(
      frame: MascotBubbles.thought,
      padding: EdgeInsets.only(right: 1),
    );
  }
}

/// Animated thought bubbles to show "thinking" while generating.
@view
class MascotThoughtBubblesAnimated extends StatelessComponent {
  const MascotThoughtBubblesAnimated({super.key});

  @override
  Component build(BuildContext context) {
    return const _AnimatedAsciiFrames(
      frames: MascotBubbles.thoughtFrames,
      interval: Duration(milliseconds: 300),
      padding: EdgeInsets.only(right: 1),
    );
  }
}

/// Animated "speaking" bubbles for the response phase.
@view
class MascotSpeakingBubblesAnimated extends StatelessComponent {
  const MascotSpeakingBubblesAnimated({super.key});

  @override
  Component build(BuildContext context) {
    return const _AnimatedAsciiFrames(
      frames: MascotBubbles.speakingFrames,
      interval: Duration(milliseconds: 220),
      padding: EdgeInsets.only(top: 1, right: 1),
    );
  }
}
