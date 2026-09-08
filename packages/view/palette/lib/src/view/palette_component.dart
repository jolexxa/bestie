import 'dart:async';

import 'package:bestie_commands_use_case/bestie_commands_use_case.dart';
import 'package:bestie_palette_view/src/state/palette_cubit.dart';
import 'package:blocterm/blocterm.dart';
import 'package:intentions/intentions.dart';
import 'package:nocterm/nocterm.dart';

/// Hosts the [PaletteCubit] for the lifetime of the app and drives its
/// session lifecycle from [paletteOpenChanges].
@view
class PaletteComponent extends StatefulComponent {
  /// Creates a [PaletteComponent].
  const PaletteComponent({
    required this.paletteOpenChanges,
    required this.onCloseRequested,
    required this.child,
    super.key,
  });

  /// Emits the router's `paletteOpen` value on every change.
  final Stream<bool> paletteOpenChanges;

  /// Requests that the router close the palette overlay.
  final VoidCallback onCloseRequested;

  /// The subtree rendered below the palette provider.
  final Component child;

  @override
  State<PaletteComponent> createState() => _PaletteComponentState();
}

class _PaletteComponentState extends State<PaletteComponent> {
  StreamSubscription<bool>? _sub;

  /// The provided cubit, captured at creation.
  PaletteCubit? _cubit;

  @override
  void initState() {
    super.initState();
    _sub = component.paletteOpenChanges.listen(_onPaletteOpenChanged);
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    super.dispose();
  }

  void _onPaletteOpenChanged(bool open) {
    final cubit = _cubit;
    if (cubit == null) return;
    if (open) {
      cubit.openSession();
    } else {
      cubit.closeSession();
    }
  }

  @override
  Component build(BuildContext context) {
    return BlocProvider<PaletteCubit>.create(
      create: (innerContext) => _cubit = PaletteCubit(
        commands: RepositoryProvider.of<CommandsUseCase>(innerContext),
      )..onCloseRequested = component.onCloseRequested,
      child: component.child,
    );
  }
}
