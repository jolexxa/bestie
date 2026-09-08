import 'dart:async';

import 'package:bestie_config_use_case/bestie_config_use_case.dart';
import 'package:bestie_config_view/bestie_config_view.dart' show AppConfigKeys;
import 'package:bestie_ui/bestie_ui.dart';
import 'package:blocterm/blocterm.dart';
import 'package:intentions/intentions.dart';
import 'package:nocterm/nocterm.dart';

/// Provides the theme to the downstream app component tree.
@view
class AppThemeProvider extends StatefulComponent {
  const AppThemeProvider({required this.child, super.key});

  final Component child;

  @override
  State<AppThemeProvider> createState() => _AppThemeProviderState();
}

class _AppThemeProviderState extends State<AppThemeProvider> {
  late final ConfigUseCase _configUseCase;
  late final AppConfigKeys _configKeys;
  late AppThemeData _theme;
  late bool _mathColors;
  StreamSubscription<String>? _themeSub;
  StreamSubscription<bool>? _mathSub;

  @override
  void initState() {
    super.initState();
    _configUseCase = RepositoryProvider.of<ConfigUseCase>(context);
    _configKeys = RepositoryProvider.of<AppConfigKeys>(context);
    _theme = _resolveTheme();
    _mathColors = _configUseCase.resolve(_configKeys.mathColors.global);
    _themeSub = _configUseCase.watch(_configKeys.themeName.global).listen((
      name,
    ) {
      final next = appThemes[name] ?? appThemeDefault;
      if (!identical(next, _theme)) {
        setState(() => _theme = next);
      }
    });
    _mathSub = _configUseCase.watch(_configKeys.mathColors.global).listen((on) {
      if (on != _mathColors) {
        setState(() => _mathColors = on);
      }
    });
  }

  @override
  void dispose() {
    unawaited(_themeSub?.cancel());
    unawaited(_mathSub?.cancel());
    _themeSub = null;
    _mathSub = null;
    super.dispose();
  }

  AppThemeData _resolveTheme() {
    final name = _configUseCase.resolve(_configKeys.themeName.global);
    return appThemes[name] ?? appThemeDefault;
  }

  @override
  Component build(BuildContext context) {
    return AppTheme(
      data: _theme,
      child: TuiTheme(
        data: _theme,
        child: MathThemeScope(
          data: _mathColors ? _theme.math : MathTheme.none,
          child: component.child,
        ),
      ),
    );
  }
}
