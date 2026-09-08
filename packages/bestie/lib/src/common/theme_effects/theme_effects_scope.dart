import 'dart:async';

import 'package:bestie_config_use_case/bestie_config_use_case.dart';
import 'package:bestie_config_view/bestie_config_view.dart' show AppConfigKeys;
import 'package:bestie_ui/bestie_ui.dart';
import 'package:blocterm/blocterm.dart';
import 'package:intentions/intentions.dart';
import 'package:nocterm/nocterm.dart';

/// Exposes the resolved `app.theme_effects` boolean to descendants and
/// rebuilds on live config changes.
///
/// Mirrors the subscription pattern in `AppThemeProvider` — listens on
/// `ConfigUseCase.changes` so toggles apply without restarting the app.
@view
class ThemeEffectsScope extends StatefulComponent {
  const ThemeEffectsScope({required this.child, super.key});

  final Component child;

  static bool of(BuildContext context) => ThemeEffects.of(context);

  @override
  State<ThemeEffectsScope> createState() => _ThemeEffectsScopeState();
}

class _ThemeEffectsScopeState extends State<ThemeEffectsScope> {
  late final ConfigUseCase _configUseCase;
  late final AppConfigKeys _configKeys;
  late bool _enabled;
  StreamSubscription<bool>? _sub;

  @override
  void initState() {
    super.initState();
    _configUseCase = RepositoryProvider.of<ConfigUseCase>(context);
    _configKeys = RepositoryProvider.of<AppConfigKeys>(context);
    _enabled = _resolve();
    _sub = _configUseCase.watch(_configKeys.themeEffects.global).listen((next) {
      if (next != _enabled) {
        setState(() => _enabled = next);
      }
    });
  }

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    _sub = null;
    super.dispose();
  }

  bool _resolve() => _configUseCase.resolve(_configKeys.themeEffects.global);

  @override
  Component build(BuildContext context) =>
      ThemeEffects(enabled: _enabled, child: component.child);
}
