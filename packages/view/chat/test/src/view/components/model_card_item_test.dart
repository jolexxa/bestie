import 'package:agent_repository/agent_repository.dart';
import 'package:bestie_chat_view/src/view/components/model_card_item.dart';
import 'package:bestie_ui/bestie_ui.dart';
import 'package:nocterm/nocterm.dart';
import 'package:test/test.dart';

Component _themed(Component child) => AppTheme(
  data: appThemeDefault,
  child: TuiTheme(data: appThemeDefault, child: child),
);

const _ready = ModelSnapshot.remote(
  modelId: 'org/model',
  displayName: 'Model',
  contextSize: 4096,
  provider: 'OpenRouter',
);

const _loading = ModelSnapshot(
  modelId: 'org/model',
  displayName: 'Model',
  contextSize: 4096,
  provider: 'OpenRouter',
  phase: ModelCardPhase.loading,
);

const _failed = ModelSnapshot(
  modelId: 'org/model',
  displayName: 'Model',
  contextSize: 4096,
  provider: 'OpenRouter',
  phase: ModelCardPhase.failed,
  error: 'Boom',
);

const _failedSilently = ModelSnapshot(
  modelId: 'org/model',
  displayName: 'Model',
  contextSize: 4096,
  provider: 'OpenRouter',
  phase: ModelCardPhase.failed,
);

/// The cell holding the phase glyph that leads the marker line.
Cell? _glyphCell(NoctermTester tester) {
  final lines = tester.terminalState.getText().split('\n');
  final row = lines.indexWhere((line) => line.contains('OpenRouter'));
  final column = lines[row].indexOf('OpenRouter') - 2;
  return tester.terminalState.getCellAt(column, row);
}

void main() {
  group('ModelCardItem', () {
    test('reads as one line: glyph, provider, and model name', () async {
      await testNocterm('model card ready', (tester) async {
        await tester.pumpComponent(
          _themed(const ModelCardItem(card: _ready, selected: false)),
        );
        expect(tester.terminalState, containsText('● OpenRouter ◆ Model'));
        expect(tester.terminalState, isNot(containsText('org/model')));
        expect(_glyphCell(tester)?.style.color, appThemeDefault.success);
        final lines = tester.terminalState.getText().split('\n');
        final row = lines.indexWhere((line) => line.contains('OpenRouter'));
        final provider = tester.terminalState.getCellAt(
          lines[row].indexOf('OpenRouter'),
          row,
        );
        expect(provider?.style.color, appThemeDefault.primary);
      });
    });

    test('marks a loading model with the loading color', () async {
      await testNocterm('model card loading', (tester) async {
        await tester.pumpComponent(
          _themed(const ModelCardItem(card: _loading, selected: false)),
        );
        expect(tester.terminalState, containsText('◑ OpenRouter ◆ Model'));
        expect(_glyphCell(tester)?.style.color, appThemeDefault.loading);
      });
    });

    test('marks a failed model and appends its error when known', () async {
      await testNocterm('model card failed', (tester) async {
        await tester.pumpComponent(
          _themed(const ModelCardItem(card: _failed, selected: false)),
        );
        expect(
          tester.terminalState,
          containsText('✕ OpenRouter ◆ Model · Boom'),
        );
        expect(_glyphCell(tester)?.style.color, appThemeDefault.error);

        await tester.pumpComponent(
          _themed(const ModelCardItem(card: _failedSilently, selected: false)),
        );
        expect(tester.terminalState, containsText('✕ OpenRouter ◆ Model'));
        expect(tester.terminalState, isNot(containsText('·')));
      });
    });

    test('goes bold when selected, keeping every color', () async {
      await testNocterm('model card selected', (tester) async {
        await tester.pumpComponent(
          _themed(const ModelCardItem(card: _ready, selected: true)),
        );
        final lines = tester.terminalState.getText().split('\n');
        final row = lines.indexWhere((line) => line.contains('OpenRouter'));
        final column = lines[row].indexOf('OpenRouter');
        final provider = tester.terminalState.getCellAt(column, row);
        expect(provider?.style.color, appThemeDefault.primary);
        expect(provider?.style.fontWeight, FontWeight.bold);
        expect(_glyphCell(tester)?.style.color, appThemeDefault.success);
      });
    });

    test('brightens the rules when hovered', () async {
      await testNocterm('model card hovered', (tester) async {
        await tester.pumpComponent(
          _themed(
            const ModelCardItem(card: _ready, selected: false, hovered: true),
          ),
        );
        final lines = tester.terminalState.getText().split('\n');
        final row = lines.indexWhere((line) => line.contains('OpenRouter'));
        final rule = tester.terminalState.getCellAt(0, row);
        expect(rule?.style.backgroundColor, appThemeDefault.muted);
      });
    });
  });
}
