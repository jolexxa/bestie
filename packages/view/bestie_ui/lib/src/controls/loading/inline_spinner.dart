import 'dart:async';

import 'package:intentions/intentions.dart';
import 'package:nocterm/nocterm.dart';

@view
class InlineSpinner extends StatefulComponent {
  const InlineSpinner({super.key, this.color, this.backgroundColor});

  /// Override for the spinner glyph color. Defaults to `theme.secondary`.
  final Color? color;

  /// Fill behind the glyph, for a spinner set on a colored band.
  final Color? backgroundColor;

  @override
  State<InlineSpinner> createState() => _InlineSpinnerState();
}

class _InlineSpinnerState extends State<InlineSpinner> {
  static const List<String> _frames = <String>[
    ' ',
    '·',
    '∶',
    '∷',
    '░',
    '▒',
    '▓',
    '█',
    '█',
    '▓',
    '▒',
    '░',
    '∷',
    '∶',
    '.',
  ];

  static const Duration _interval = Duration(milliseconds: 120);

  Timer? _timer;
  var _index = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_interval, (_) {
      if (!mounted) return;
      setState(() {
        _index = (_index + 1) % _frames.length;
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
    final theme = TuiTheme.of(context);
    return Text(
      _frames[_index],
      style: TextStyle(
        color: component.color ?? theme.secondary,
        backgroundColor: component.backgroundColor,
      ),
    );
  }
}
