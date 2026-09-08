// Tests are clearer with explicit `repo.x; repo.y;` than cascades.
// ignore_for_file: cascade_invocations

import 'dart:io';

import 'package:bestie_config/bestie_config.dart';
import 'package:bestie_config_use_case/bestie_config_use_case.dart';
import 'package:bestie_config_view/src/schema/bestie_config_keys.dart';
import 'package:bestie_config_view/src/schema/config_schema.dart';
import 'package:bestie_config_view/src/state/config_cubit.dart';
import 'package:bestie_config_view/src/state/config_logic.dart';
import 'package:bestie_config_view/src/state/info_layout.dart';
import 'package:config_repository/config_repository.dart';
import 'package:test/test.dart';

const _defaultPrompt = 'test prompt';

ConfigCubit _buildCubit({
  required ConfigUseCase useCase,
  required ConfigLayout layout,
  int toolCount = 0,
  ConfigScope? targetScope,
}) => ConfigCubit(
  configUseCase: useCase,
  layout: layout,
  toolCount: toolCount,
  targetScope: targetScope,
);

ConfigScope _modelScope(String modelId) =>
    ConfigScope.path(['models', modelId]);

bool _hasUserValue(
  ConfigView resolver,
  ConfigAddressBase address,
) => resolver.isExplicitBase(address);

void main() {
  late Directory tmp;
  late ConfigRepository repo;
  late ConfigUseCase useCase;
  late BestieConfigKeys keys;
  late ConfigLayout layout;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('cow_config_cubit_test_');
    final store = ConfigDataSource(configFile: '${tmp.path}/bestie.json')
      ..load();
    final schema = buildConfigSchema(
      defaultSystemPrompt: _defaultPrompt,
      defaultTheme: 'Jelly Bean',
      availableThemes: const ['Jelly Bean', 'Neo'],
    );
    keys = schema.keys;
    layout = schema.layout;
    repo = ConfigRepository(
      dataSource: store,
    );
    useCase = ConfigUseCase(repo);
  });

  tearDown(() async {
    await useCase.dispose();
    tmp.deleteSync(recursive: true);
  });

  test('openSession refreshes target scope and tool count', () async {
    final cubit = _buildCubit(
      useCase: useCase,
      layout: layout,
    );
    addTearDown(cubit.close);

    // Initial state has no scoped config target.
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.data.targetScope, isNull);
    expect(cubit.state.data.toolCount, 0);

    cubit.openSession(targetScope: _modelScope('qwen3-test'), toolCount: 7);
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.data.targetScope, _modelScope('qwen3-test'));
    expect(cubit.state.data.toolCount, 7);

    cubit.closeSession();
  });

  test('selectedPageId survives across openSession calls', () async {
    final cubit = _buildCubit(
      useCase: useCase,
      layout: layout,
    );
    addTearDown(cubit.close);

    await Future<void>.delayed(Duration.zero);
    final initial = cubit.state.data.selectedPageId;

    // Walk forward two pages, then assert the new page sticks.
    cubit.changePage(1);
    cubit.changePage(1);
    await Future<void>.delayed(Duration.zero);

    final after = cubit.state.data.selectedPageId;
    expect(after, isNot(initial));

    // openSession (called by the router on each open) must NOT reset
    // selectedPageId — it only refreshes target scope + tool count.
    cubit.openSession(targetScope: _modelScope('whatever'), toolCount: 0);
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.data.selectedPageId, after);
    cubit.closeSession();
  });

  test('document pages disable selection; info sizes to its rows', () async {
    final cubit = _buildCubit(
      useCase: useCase,
      layout: layout,
      toolCount: 3,
    );
    addTearDown(cubit.close);
    await Future<void>.delayed(Duration.zero);

    final pageCount = layout.pages.length;
    Future<void> goTo(String id) async {
      for (var i = 0; i < pageCount; i++) {
        if (cubit.state.data.selectedPageId == id) break;
        cubit.changePage(1);
        await Future<void>.delayed(Duration.zero);
      }
      expect(cubit.state.data.selectedPageId, id);
    }

    // Info (a selectable list) sizes selection to its runtime row count.
    await goTo('info');
    expect(cubit.state.selectionMax, infoSelectableCount(toolCount: 3) - 1);

    // Credits (a document) has nothing to select; arrows stay inert.
    await goTo('credits');
    expect(cubit.state.selectionMax, -1);
    cubit.moveSelection(1);
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.selectedIndex, 0);

    cubit.closeSession();
  });

  test('app config writes through the config use case', () async {
    final cubit = _buildCubit(
      useCase: useCase,
      layout: layout,
    );
    addTearDown(cubit.close);

    cubit.openSession(targetScope: _modelScope('qwen3-test'), toolCount: 0);
    await Future<void>.delayed(Duration.zero);

    // Initial page is App; selected row is the theme entry.
    cubit.adjustValue(1);
    await Future<void>.delayed(Duration.zero);
    cubit.closeSession();
    await Future<void>.delayed(Duration.zero);

    expect(repo.resolve(keys.app.themeName.global), 'Neo');
  });

  test('provider sampling writes through the config use case', () async {
    final cubit = _buildCubit(useCase: useCase, layout: layout);
    addTearDown(cubit.close);

    cubit.openSession(toolCount: 0);
    await Future<void>.delayed(Duration.zero);

    // App -> Agent -> Provider. Sampling temperature sits below the five
    // account rows and max agents.
    cubit.changePage(1);
    cubit.changePage(1);
    cubit.moveSelection(6);
    cubit.adjustValue(1);
    cubit.adjustValue(1);
    await Future<void>.delayed(Duration.zero);
    cubit.closeSession();
    await Future<void>.delayed(Duration.zero);

    expect(
      _hasUserValue(repo, keys.provider.sampling.temperature.global),
      true,
    );
  });

  test('provider max agents writes through the config use case', () async {
    final cubit = _buildCubit(useCase: useCase, layout: layout);
    addTearDown(cubit.close);

    cubit.openSession(toolCount: 0);
    await Future<void>.delayed(Duration.zero);

    // App -> Agent -> Provider. Max agents follows the five account rows.
    cubit.changePage(1);
    cubit.changePage(1);
    cubit.moveSelection(5);
    cubit.adjustValue(1);
    await Future<void>.delayed(Duration.zero);
    cubit.closeSession();
    await Future<void>.delayed(Duration.zero);

    expect(_hasUserValue(repo, keys.provider.maxAgents.global), true);
  });

  test('opaque text config ignores inline adjust', () async {
    final cubit = _buildCubit(
      useCase: useCase,
      layout: layout,
    );
    addTearDown(cubit.close);

    cubit.openSession(targetScope: _modelScope('qwen3-test'), toolCount: 0);
    await Future<void>.delayed(Duration.zero);

    // App -> Agent. First agent row is the multi-line system prompt.
    cubit.changePage(1);
    cubit.adjustValue(1);
    await Future<void>.delayed(Duration.zero);
    cubit.closeSession();
    await Future<void>.delayed(Duration.zero);

    expect(_hasUserValue(repo, keys.chat.systemPrompt.global), isFalse);
    expect(repo.resolve(keys.chat.systemPrompt.global), _defaultPrompt);
  });

  test('cancel edit does not pin default value', () async {
    final cubit = _buildCubit(
      useCase: useCase,
      layout: layout,
    );
    addTearDown(cubit.close);

    cubit.openSession(targetScope: _modelScope('qwen3-test'), toolCount: 0);
    await Future<void>.delayed(Duration.zero);

    // App -> Agent. Begin edit enters the prompt text field, but
    // canceling should leave the inherited/default value implicit.
    cubit.changePage(1);
    cubit.beginEdit();
    await Future<void>.delayed(Duration.zero);
    cubit.cancelEdit();
    await Future<void>.delayed(Duration.zero);
    cubit.closeSession();
    await Future<void>.delayed(Duration.zero);

    expect(_hasUserValue(repo, keys.chat.systemPrompt.global), isFalse);
    expect(repo.resolve(keys.chat.systemPrompt.global), _defaultPrompt);
  });

  test('closeSession exits text editing before reopening', () async {
    final cubit = _buildCubit(
      useCase: useCase,
      layout: layout,
    );
    addTearDown(cubit.close);

    cubit.openSession(targetScope: _modelScope('qwen3-test'), toolCount: 0);
    await Future<void>.delayed(Duration.zero);

    // App -> Agent. First agent row is the multi-line system prompt.
    cubit.changePage(1);
    cubit.beginEdit();
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state, isA<EditingState>());

    cubit.closeSession();
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state, isA<BrowsingState>());

    cubit.openSession(targetScope: _modelScope('qwen3-test'), toolCount: 0);
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state, isA<BrowsingState>());
    expect(repo.resolve(keys.chat.systemPrompt.global), _defaultPrompt);
  });

  test(
    'changing page while editing returns to browsing on the new page',
    () async {
      final cubit = _buildCubit(
        useCase: useCase,
        layout: layout,
      );
      addTearDown(cubit.close);

      cubit.openSession(targetScope: _modelScope('qwen3-test'), toolCount: 0);
      await Future<void>.delayed(Duration.zero);

      // App -> Agent, then begin editing the multi-line system prompt.
      cubit.changePage(1);
      cubit.beginEdit();
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state, isA<EditingState>());
      final editingPage = cubit.state.data.selectedPageId;

      // Tab while editing advances the page and drops back to browsing,
      // with the selection reset to the top of the new page.
      cubit.changePage(1);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state, isA<BrowsingState>());
      expect(cubit.state.data.selectedPageId, isNot(editingPage));
      expect(cubit.state.selectedIndex, 0);

      cubit.closeSession();
    },
  );
}
