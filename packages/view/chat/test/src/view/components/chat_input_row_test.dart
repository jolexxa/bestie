import 'package:agent_repository/agent_repository.dart';
import 'package:bestie_chat_use_case/bestie_chat_use_case.dart';
import 'package:bestie_chat_view/src/state/chat_logic.dart';
import 'package:bestie_chat_view/src/view/components/chat_input_row.dart';
import 'package:bestie_provider_use_case/bestie_provider_use_case.dart';
import 'package:bestie_sandbox_use_case/bestie_sandbox_use_case.dart';
import 'package:bestie_tools_use_case/bestie_tools_use_case.dart';
import 'package:bestie_ui/bestie_ui.dart';
import 'package:blocterm/blocterm.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nocterm/nocterm.dart';
import 'package:platform_repository/platform_repository.dart';
import 'package:provider_repository/provider_repository.dart';
import 'package:sandbox_repository/sandbox_repository.dart';
import 'package:test/test.dart';

class _MockChatUseCase extends Mock implements ChatUseCase {}

class _MockProviderUseCase extends Mock implements ProviderUseCase {}

class _MockToolsUseCase extends Mock implements ToolsUseCase {}

class _MockSandboxUseCase extends Mock implements SandboxUseCase {}

class _MockOSPlatformRepository extends Mock implements OSPlatformRepository {}

const _size = Size(60, 8);

/// Where the field's first character sits, past the `> ` prompt.
const _fieldX = 2;

ChatLogic _logic() {
  final useCase = _MockChatUseCase();
  final provider = _MockProviderUseCase();
  final tools = _MockToolsUseCase();
  final sandbox = _MockSandboxUseCase();
  when(() => sandbox.readiness).thenReturn(const SandboxReady());
  when(() => sandbox.readinessStream).thenAnswer((_) => const Stream.empty());
  when(() => sandbox.pendingWriteAccess).thenReturn(null);
  when(
    () => sandbox.pendingWriteAccessStream,
  ).thenAnswer((_) => const Stream.empty());
  const idle = ConversationIdle(
    timelineItems: <TimelineItem>[],
    conversationPhase: ConversationPhase.idle,
  );
  when(() => useCase.conversationState).thenReturn(idle);
  when(() => useCase.viewedConversationState).thenReturn(idle);
  when(() => provider.status).thenReturn(const ProviderStatusUnconfigured());
  when(() => provider.statusStream).thenAnswer((_) => const Stream.empty());
  when(
    () => useCase.conversationStream,
  ).thenAnswer((_) => const Stream.empty());
  when(
    () => useCase.subagentSummariesStream,
  ).thenAnswer((_) => const Stream.empty());
  when(
    () => useCase.conversationReplacements,
  ).thenAnswer((_) => const Stream.empty());
  when(() => useCase.rewindRequests).thenAnswer((_) => const Stream.empty());
  when(() => tools.activeJobCount).thenReturn(0);
  when(() => tools.activeJobs).thenAnswer((_) => const Stream.empty());
  return ChatLogic(
    useCase: useCase,
    providerUseCase: provider,
    toolsUseCase: tools,
    sandboxUseCase: sandbox,
  );
}

Future<void> _drag(NoctermTester tester, int fromX, int toX) async {
  await tester.sendMouseEvent(
    MouseEvent(button: MouseButton.left, x: fromX, y: 0, pressed: true),
  );
  await tester.sendMouseEvent(
    MouseEvent(
      button: MouseButton.left,
      x: toX,
      y: 0,
      pressed: true,
      isMotion: true,
      buttons: const {MouseButton.left},
    ),
  );
  await tester.sendMouseEvent(
    MouseEvent(button: MouseButton.left, x: toX, y: 0, pressed: false),
  );
  await tester.pump();
}

void main() {
  late ChatLogic logic;
  late TextEditingController textController;
  late _MockOSPlatformRepository platform;
  late int quits;

  setUp(() {
    logic = _logic()..start();
    textController = TextEditingController(text: 'Hello World');
    platform = _MockOSPlatformRepository();
    when(() => platform.copyToClipboard(any())).thenAnswer((_) async {});
    quits = 0;
  });

  tearDown(() {
    textController.dispose();
    logic
      ..stop()
      ..dispose();
  });

  Future<void> pumpRow(NoctermTester tester) => tester.pumpComponent(
    RepositoryProvider<OSPlatformRepository>.value(
      value: platform,
      child: Provider<RouterContext>(
        value: RouterContext(
          mode: AppMode.chat,
          overlayOpen: false,
          switchToMode: (_) {},
        ),
        child: InputActions(
          actions: [
            KeyAction(
              label: 'Quit',
              key: LogicalKey.keyC,
              ctrl: true,
              onActivate: () => quits++,
            ),
          ],
          child: AppTheme(
            data: appThemeDefault,
            child: TuiTheme(
              data: appThemeDefault,
              child: ChatInputRow(
                textController: textController,
                state: logic.value,
                onSubmitted: () {},
                onEnterZone: () {},
              ),
            ),
          ),
        ),
      ),
    ),
  );

  test('a mouse drag copies the selection and then unselects', () async {
    await testNocterm('composer drag', size: _size, (tester) async {
      await pumpRow(tester);

      await _drag(tester, _fieldX + 1, _fieldX + 4);

      verify(() => platform.copyToClipboard('ell')).called(1);
      expect(
        textController.selection,
        const TextSelection.collapsed(offset: 4),
      );
    });
  });

  test('a paste lands whole, past the visible rows', () async {
    await testNocterm('composer paste', size: _size, (tester) async {
      textController.text = '';
      await pumpRow(tester);
      final lines = List.generate(8, (index) => 'line ${index + 1}');

      await tester.paste(lines.join('\r\n'));

      expect(textController.text.split('\n'), lines);
      verifyNever(() => platform.copyToClipboard(any()));
    });
  });

  test('Ctrl+C quits even with a selection', () async {
    await testNocterm('composer ctrl+c', size: _size, (tester) async {
      await pumpRow(tester);
      await tester.sendKeyEvent(
        const KeyboardEvent(
          logicalKey: LogicalKey.keyA,
          modifiers: ModifierKeys(ctrl: true),
        ),
      );
      expect(textController.selection.isCollapsed, isFalse);

      await tester.sendKeyEvent(
        const KeyboardEvent(
          logicalKey: LogicalKey.keyC,
          modifiers: ModifierKeys(ctrl: true),
        ),
      );

      expect(quits, 1);
      verifyNever(() => platform.copyToClipboard(any()));
    });
  });
}
