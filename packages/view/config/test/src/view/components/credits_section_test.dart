import 'package:bestie_config_view/src/models/credits_document.dart';
import 'package:bestie_config_view/src/view/components/credits_section.dart';
import 'package:bestie_ui/bestie_ui.dart';
import 'package:blocterm/blocterm.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nocterm/nocterm.dart';
import 'package:platform_repository/platform_repository.dart';
import 'package:test/test.dart';

class _MockOSPlatformRepository extends Mock implements OSPlatformRepository {}

const _markdown = '''
# Credits

Bestie stands on the shoulders of giants.

## MIT

| Package | Copyright     |
|---------|---------------|
| bloc    | Felix Angelov |
''';

void main() {
  test('renders the credits markdown, including tables', () async {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await testNocterm('credits render', (tester) async {
      await tester.pumpComponent(
        MultiRepositoryProvider(
          providers: [
            const RepositoryProvider<CreditsDocument>.value(
              value: CreditsDocument(markdown: _markdown),
            ),
            RepositoryProvider<OSPlatformRepository>.value(
              value: _MockOSPlatformRepository(),
            ),
          ],
          child: TuiTheme(
            data: appThemeDefault,
            child: AppTheme(
              data: appThemeDefault,
              child: CreditsSection(controller: controller),
            ),
          ),
        ),
      );

      final text = tester.terminalState.getText();
      expect(text, contains('giants'));
      expect(text, contains('MIT'));
      expect(text, contains('bloc'));
      expect(text, contains('Felix Angelov'));
    });
  });
}
