import 'dart:io';

import 'package:bestie/src/app/app_theme_provider.dart';
import 'package:bestie_config/bestie_config.dart';
import 'package:bestie_config_view/bestie_config_view.dart';
import 'package:bestie_ui/bestie_ui.dart';
import 'package:blocterm/blocterm.dart';
import 'package:config_repository/config_repository.dart';
import 'package:nocterm/nocterm.dart';
import 'package:test/test.dart';

/// Captures the resolved theme name visible from the child's context.
class _Capture extends StatelessComponent {
  const _Capture({required this.onBuild});
  final void Function(String themeName) onBuild;

  @override
  Component build(BuildContext context) {
    onBuild(AppTheme.of(context).name);
    return const SizedBox();
  }
}

/// Captures the math theme visible from the child's context.
class _CaptureMath extends StatelessComponent {
  const _CaptureMath({required this.onBuild});
  final void Function(MathTheme theme) onBuild;

  @override
  Component build(BuildContext context) {
    onBuild(MathThemeScope.of(context));
    return const SizedBox();
  }
}

({
  ConfigRepository repo,
  ConfigUseCase useCase,
  AppConfigKeys keys,
})
_setup(Directory tmp) {
  final store = ConfigDataSource(configFile: '${tmp.path}/bestie.json')..load();
  final keys = AppConfigKeys.defaults(defaultTheme: appThemeDefault.name);
  final repo = ConfigRepository(dataSource: store);
  final useCase = ConfigUseCase(repo);
  return (repo: repo, useCase: useCase, keys: keys);
}

void main() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('app_theme_provider_test_');
  });

  tearDown(() {
    tmp.deleteSync(recursive: true);
  });

  test(
    'initial build resolves the default theme when no override is set',
    () async {
      final s = _setup(tmp);
      addTearDown(s.useCase.dispose);

      await testNocterm('default theme', (tester) async {
        String? captured;
        await tester.pumpComponent(
          MultiRepositoryProvider(
            providers: [
              RepositoryProvider<ConfigUseCase>.value(value: s.useCase),
              RepositoryProvider<AppConfigKeys>.value(value: s.keys),
            ],
            child: AppThemeProvider(
              child: _Capture(onBuild: (name) => captured = name),
            ),
          ),
        );
        expect(captured, appThemeDefault.name);
      });
    },
  );

  test(
    'flipping the theme name rebuilds the child with the new theme',
    () async {
      final s = _setup(tmp);
      addTearDown(s.useCase.dispose);

      await testNocterm('flip theme', (tester) async {
        final captured = <String>[];
        await tester.pumpComponent(
          MultiRepositoryProvider(
            providers: [
              RepositoryProvider<ConfigUseCase>.value(value: s.useCase),
              RepositoryProvider<AppConfigKeys>.value(value: s.keys),
            ],
            child: AppThemeProvider(
              child: _Capture(onBuild: captured.add),
            ),
          ),
        );
        expect(captured.last, appThemeDefault.name);

        s.useCase.update(
          s.keys.themeName.global,
          const ConfigEdit.set('Hot Cocoa'),
        );
        // Drain the broadcast-stream microtask, then pump one frame.
        await Future<void>.delayed(Duration.zero);
        await tester.pump();

        expect(captured.last, 'Hot Cocoa');
      });
    },
  );

  test('unknown theme name falls back to the default', () async {
    final s = _setup(tmp);
    addTearDown(s.useCase.dispose);

    await testNocterm('unknown theme falls back', (tester) async {
      String? captured;
      s.repo.commit({
        s.keys.themeName.global: const ConfigEdit.set('Nonexistent Theme Name'),
      });

      await tester.pumpComponent(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider<ConfigUseCase>.value(value: s.useCase),
            RepositoryProvider<AppConfigKeys>.value(value: s.keys),
          ],
          child: AppThemeProvider(
            child: _Capture(onBuild: (name) => captured = name),
          ),
        ),
      );

      expect(captured, appThemeDefault.name);
    });
  });

  test('provides the math styling of the active theme by default', () async {
    final s = _setup(tmp);
    addTearDown(s.useCase.dispose);

    await testNocterm('default math colors', (tester) async {
      MathTheme? captured;
      await tester.pumpComponent(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider<ConfigUseCase>.value(value: s.useCase),
            RepositoryProvider<AppConfigKeys>.value(value: s.keys),
          ],
          child: AppThemeProvider(
            child: _CaptureMath(onBuild: (theme) => captured = theme),
          ),
        ),
      );

      expect(
        captured,
        appThemeDefault.math,
      );
    });
  });

  test('turning math colors off stops painting equations', () async {
    final s = _setup(tmp);
    addTearDown(s.useCase.dispose);

    await testNocterm('math colors off', (tester) async {
      final captured = <MathTheme>[];
      await tester.pumpComponent(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider<ConfigUseCase>.value(value: s.useCase),
            RepositoryProvider<AppConfigKeys>.value(value: s.keys),
          ],
          child: AppThemeProvider(
            child: _CaptureMath(onBuild: captured.add),
          ),
        ),
      );
      expect(captured.last.isPlain, isFalse);

      s.useCase.update(s.keys.mathColors.global, const ConfigEdit.set(false));
      // Drain the broadcast-stream microtask, then pump one frame.
      await Future<void>.delayed(Duration.zero);
      await tester.pump();

      expect(captured.last, same(MathTheme.none));
    });
  });

  test('stops following config once it is unmounted', () async {
    final s = _setup(tmp);
    addTearDown(s.useCase.dispose);

    await testNocterm('unmount', (tester) async {
      final captured = <String>[];
      Component hosting(Component child) => MultiRepositoryProvider(
        providers: [
          RepositoryProvider<ConfigUseCase>.value(value: s.useCase),
          RepositoryProvider<AppConfigKeys>.value(value: s.keys),
        ],
        child: child,
      );

      await tester.pumpComponent(
        hosting(AppThemeProvider(child: _Capture(onBuild: captured.add))),
      );
      expect(captured.last, appThemeDefault.name);

      // Swap the provider out so it unmounts while the config it was watching
      // outlives it.
      await tester.pumpComponent(hosting(const SizedBox()));
      final builds = captured.length;

      s.useCase.update(
        s.keys.themeName.global,
        const ConfigEdit.set('Hot Cocoa'),
      );
      await Future<void>.delayed(Duration.zero);
      await tester.pump();

      // A subscription that outlived the state would call setState on it.
      expect(captured, hasLength(builds));
    });
  });

  test('math styling follows a theme change', () async {
    final s = _setup(tmp);
    addTearDown(s.useCase.dispose);

    await testNocterm('math follows theme', (tester) async {
      final captured = <MathTheme>[];
      await tester.pumpComponent(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider<ConfigUseCase>.value(value: s.useCase),
            RepositoryProvider<AppConfigKeys>.value(value: s.keys),
          ],
          child: AppThemeProvider(
            child: _CaptureMath(onBuild: captured.add),
          ),
        ),
      );
      expect(captured.last, appThemeDefault.math);

      s.useCase.update(
        s.keys.themeName.global,
        const ConfigEdit.set('Hot Cocoa'),
      );
      // Drain the broadcast-stream microtask, then pump one frame.
      await Future<void>.delayed(Duration.zero);
      await tester.pump();

      expect(captured.last, appThemes['Hot Cocoa']!.math);
    });
  });
}
