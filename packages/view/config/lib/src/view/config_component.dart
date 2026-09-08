import 'dart:async';

import 'package:bestie_config_use_case/bestie_config_use_case.dart';
import 'package:bestie_config_view/src/state/config_cubit.dart';
import 'package:blocterm/blocterm.dart';
import 'package:intentions/intentions.dart';
import 'package:nocterm/nocterm.dart';
import 'package:tool_protocol/tool_protocol.dart' show ToolDefinitions;

/// Hosts the [ConfigCubit] for the lifetime of the app and drives its
/// session lifecycle from [configOpenChanges].
///
/// Mounted once, above [child] (which renders the conditional
/// `ConfigPageView` somewhere inside it), so the cubit's state
/// (selectedPage, selectedIndex, etc.) survives open / close toggles.
/// Reacts to [configOpenChanges] rather than reading a plain `bool`
/// prop, since a rebuild here would tear down and recreate the cubit —
/// see `BlocProvider`'s `create`-identity check.
@view
class ConfigComponent extends StatefulComponent {
  /// Creates a [ConfigComponent].
  const ConfigComponent({
    required this.configOpenChanges,
    required this.onCloseRequested,
    required this.child,
    super.key,
  });

  /// Emits the router's `configOpen` value on every change.
  final Stream<bool> configOpenChanges;

  /// Requests that the router close the config overlay.
  final VoidCallback onCloseRequested;

  /// The subtree rendered below the config provider. The conditional
  /// `ConfigPageView` lives somewhere inside this subtree and reads the
  /// cubit from the ancestral provider.
  final Component child;

  @override
  State<ConfigComponent> createState() => _ConfigComponentState();
}

class _ConfigComponentState extends State<ConfigComponent> {
  StreamSubscription<bool>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = component.configOpenChanges.listen(_onConfigOpenChanged);
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    super.dispose();
  }

  void _onConfigOpenChanged(bool open) {
    final cubit = BlocProvider.of<ConfigCubit>(context, listen: false);
    if (!open) {
      cubit.closeSession();
      return;
    }
    final tools = RepositoryProvider.of<ToolDefinitions>(context);
    cubit.openSession(toolCount: tools.definitions.length);
  }

  @override
  Component build(BuildContext context) {
    return BlocProvider<ConfigCubit>.create(
      create: (innerContext) => ConfigCubit(
        configUseCase: RepositoryProvider.of<ConfigUseCase>(innerContext),
        layout: RepositoryProvider.of<ConfigLayout>(innerContext),
        toolCount: RepositoryProvider.of<ToolDefinitions>(
          innerContext,
        ).definitions.length,
      )..onCloseRequested = component.onCloseRequested,
      child: component.child,
    );
  }
}
