import 'package:app_shell_use_case/app_shell_use_case.dart';
import 'package:bestie/src/app/router/router.dart';
import 'package:bestie_ui/bestie_ui.dart' show AppMode;
import 'package:test/test.dart';

void main() {
  group('RouterLogic', () {
    late AppShellUseCase appShell;
    late RouterLogic logic;

    setUp(() {
      appShell = AppShellUseCase();
      logic = RouterLogic(appShell: appShell)..start();
    });

    tearDown(() async {
      logic.dispose();
      await appShell.dispose();
    });

    test('mirrors the app shell overlay visibility', () async {
      expect(logic.value.paletteOpen, isFalse);
      expect(logic.value.configOpen, isFalse);
      expect(logic.value.overlayOpen, isFalse);

      appShell.togglePalette();
      await Future<void>.delayed(Duration.zero);
      expect(logic.value.paletteOpen, isTrue);
      expect(logic.value.overlayOpen, isTrue);

      // Exclusivity lives in the shell; the router just reflects the result.
      appShell.openConfig();
      await Future<void>.delayed(Duration.zero);
      expect(logic.value.paletteOpen, isFalse);
      expect(logic.value.configOpen, isTrue);

      appShell.closeConfig();
      await Future<void>.delayed(Duration.zero);
      expect(logic.value.overlayOpen, isFalse);
    });

    test('cycles and jumps the app mode', () {
      expect(logic.value.mode, AppMode.chat);

      logic.input(const NextMode());
      expect(logic.value.mode, AppMode.chat);

      logic.input(const PreviousMode());
      expect(logic.value.mode, AppMode.chat);

      logic.input(const SwitchToMode(AppMode.chat));
      expect(logic.value.mode, AppMode.chat);
    });
  });
}
