import 'dart:async';

import 'package:agent_repository/agent_repository.dart';
import 'package:bestie_chat_use_case/bestie_chat_use_case.dart';
import 'package:bestie_chat_view/src/state/chat_cubit.dart';
import 'package:bestie_chat_view/src/state/chat_data.dart' show reasoningAuto;
import 'package:bestie_chat_view/src/state/chat_logic.dart';
import 'package:bestie_chat_view/src/state/chat_output.dart'
    show
        ChatOutput,
        ConversationSwitched,
        CursorMoved,
        ItemSelected,
        MessageAccepted,
        StateUpdated,
        TurnErrorLog;
import 'package:bestie_chat_view/src/state/composer_mode.dart';
import 'package:bestie_chat_view/src/state/selection/selection_position.dart';
import 'package:bestie_chat_view/src/view/components/components.dart';
import 'package:bestie_chat_view/src/view/details/item_details.dart'
    show DetailsTab;
import 'package:bestie_chat_view/src/view/details/item_details_mapping.dart';
import 'package:bestie_chat_view/src/workspace/shell_workspace.dart';
import 'package:bestie_chat_view/src/workspace/state/shell_workspace_cubit.dart';
import 'package:bestie_provider_use_case/bestie_provider_use_case.dart';
import 'package:bestie_sandbox_use_case/bestie_sandbox_use_case.dart';
import 'package:bestie_shell_use_case/bestie_shell_use_case.dart';
import 'package:bestie_tools_use_case/bestie_tools_use_case.dart';
import 'package:bestie_ui/bestie_ui.dart';
import 'package:blocterm/blocterm.dart';
import 'package:intentions/intentions.dart';
import 'package:markdown_highlighted/markdown_highlighted.dart';
import 'package:nocterm/nocterm.dart' hide MarkdownStyleSheet, MarkdownText;
import 'package:platform_repository/platform_repository.dart';

/// Wires a [ChatCubit] for the surrounding [BuildContext].
///
/// Reads [ChatUseCase] and friends from the ambient `RepositoryProvider`s.
/// Schedules initialization via microtask so
/// the cubit can be provided to the widget tree before the first
/// input fires.
ChatCubit _createChatCubit(BuildContext context) {
  final useCase = RepositoryProvider.of<ChatUseCase>(context);
  final providerUseCase = RepositoryProvider.of<ProviderUseCase>(context);
  final toolsUseCase = RepositoryProvider.of<ToolsUseCase>(context);
  final sandboxUseCase = RepositoryProvider.of<SandboxUseCase>(context);

  final logic = ChatLogic(
    useCase: useCase,
    providerUseCase: providerUseCase,
    toolsUseCase: toolsUseCase,
    sandboxUseCase: sandboxUseCase,
  );

  final chatCubit = ChatCubit(logic: logic);
  unawaited(Future.microtask(chatCubit.initialize));
  return chatCubit;
}

@view
class ChatPageView extends StatelessComponent {
  const ChatPageView({super.key});

  @override
  Component build(BuildContext context) {
    return const BlocProvider<ChatCubit>.create(
      create: _createChatCubit,
      child: ChatPage(),
    );
  }
}

@view
class ChatPage extends StatefulComponent {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final ViewportListScrollController _scrollController =
      ViewportListScrollController();
  final TextEditingController _textController = TextEditingController();

  // Stable across swaps.
  final GlobalKey _mascotKey = GlobalKey();

  late final ChatCubit _chatCubit;

  /// The tab host beside the chat list. Owned here rather than by
  /// [ShellWorkspace] so the page — the common ancestor of both view models —
  /// can pull the details tab forward when the user selects a message.
  late final ShellWorkspaceCubit _workspaceCubit;

  /// The page's subscription to the chat's outputs, for the signals it has to
  /// act on: clearing the input, scrolling to the cursor, showing a banner.
  late final StreamSubscription<ChatOutput> _chatOutputs;

  /// Built once and handed to every rebuild by identity, so a chat state tick
  /// — one per streamed token — stops at this boundary instead of repainting
  /// a live terminal. Only the details tab itself listens to chat state, and
  /// it isn't even built while a shell tab is on screen.
  late final Component _detailsPane = LayoutBuilder(
    builder: (context, constraints) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: _workspace(context)),
        if (constraints.maxHeight >= _minRowsForTitleBand)
          TitleBand(version: RepositoryProvider.of<AppInfo>(context).version),
      ],
    ),
  );

  /// Rows the details column needs before it gives three to the nameplate.
  static const double _minRowsForTitleBand = 15;

  Component _workspace(BuildContext context) => ShellWorkspace(
    cubit: _workspaceCubit,
    active: Provider.of<RouterContext>(context).focusFor(AppMode.chat),
    pinnedTabs: [
      WorkspacePinnedTab(
        id: propertiesTabId,
        label: '{ }',
        child: BlocBuilder<ChatCubit, ChatState>(
          bloc: _chatCubit,
          builder: (context, state) => MessageDetailsPane(
            selected: state.selectedTimelineItem,
            tab: DetailsTab.properties,
          ),
        ),
      ),
      WorkspacePinnedTab(
        id: detailsTabId,
        label: 'Details',
        // Details is the pane's default face, so the tab is left implicit.
        child: BlocBuilder<ChatCubit, ChatState>(
          bloc: _chatCubit,
          builder: (context, state) =>
              MessageDetailsPane(selected: state.selectedTimelineItem),
        ),
      ),
    ],
  );

  @override
  void initState() {
    super.initState();
    _workspaceCubit = ShellWorkspaceCubit(
      logic: ShellWorkspaceLogic(
        shell: RepositoryProvider.of<ShellUseCase>(context),
      ),
    );
    _chatCubit = BlocProvider.of<ChatCubit>(context, listen: false);
    _chatOutputs = _chatCubit.outputsOf<ChatOutput>().listen(_onChatOutput);
  }

  /// The signals a rebuild cannot carry. Sealed, so an output added later
  /// makes this switch fail to compile until the page has said whether the
  /// page is the thing that should act on it.
  void _onChatOutput(ChatOutput output) {
    switch (output) {
      case MessageAccepted():
        _textController.clear();
      case ConversationSwitched(:final replacement):
        _onConversationSwitched(replacement);
        _syncPinnedTabs();
      case ItemSelected():
        _onItemSelected();
      case CursorMoved(:final position):
        _syncPinnedTabs();
        _onCursorMoved(position);
      case StateUpdated() || TurnErrorLog():
        break;
    }
  }

  @override
  void dispose() {
    unawaited(_chatOutputs.cancel());
    unawaited(_workspaceCubit.close());
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Picking a message is a request to read it, so the pinned area comes
  /// forward — even when a shell tab was covering it — on its sticky tab.
  void _onItemSelected() {
    _syncPinnedTabs();
    _workspaceCubit.showPinnedArea();
  }

  /// Tells the workspace which pinned tabs the current selection can show.
  void _syncPinnedTabs() {
    final details = _chatCubit.state.selectedTimelineItem?.asItemDetails;
    final hasProperties = details?.properties.isNotEmpty ?? false;
    final hasContent = details?.content.isNotEmpty ?? false;
    _workspaceCubit.syncPinnedTabs([
      if (hasProperties) propertiesTabId,
      if (hasContent || !hasProperties) detailsTabId,
    ]);
  }

  void _onConversationSwitched(ConversationReplacement replacement) {
    if (replacement case RewoundToMessage(:final message)) {
      _textController
        ..text = message
        ..selection = TextSelection.collapsed(offset: message.length);
    }
    if (!mounted) return;
    BannerNotifier.of(context).show(
      BannerNotification(
        message: switch (replacement) {
          StartedFresh() => 'New conversation started',
          LoadedFromDisk() => 'Conversation loaded',
          RewoundToMessage() => 'Rewound to your message',
        },
        icon: '✦',
        style: BannerStyle.info,
      ),
    );
  }

  void _onCursorMoved(SelectionPosition position) {
    // Defer until after the next render so a tail-following cursor
    // that just rode onto a freshly-arrived item (e.g. the user's
    // just-sent message) finds the item laid out.
    TerminalBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollController.ensureIndexVisible(index: position.itemIndex);
    });
  }

  void _sendMessage() => _chatCubit.submit(_textController.text);

  static const double _pageFraction = 0.25;

  /// Steps the cursor onto the neighboring message when that message starts
  /// on screen; otherwise scrolls a quarter viewport, which is how a message
  /// taller than the viewport gets read. A cursor that drifted off screen
  /// first snaps back onto the visible edge.
  void _page(ChatState state, {required bool up}) {
    final itemCount = state.timelineItems.length;
    final selected = state.effectiveSelectedIndex;
    if (!_scrollController.isItemVisible(selected)) {
      final edge = up
          ? _scrollController.firstVisibleIndex(itemCount)
          : _scrollController.lastVisibleIndex(itemCount);
      if (edge != null) _chatCubit.selectVisibleItem(edge);
      return;
    }
    final neighbor = up ? selected - 1 : selected + 1;
    final neighborExists = neighbor >= 0 && neighbor < itemCount;
    if (neighborExists && _scrollController.isItemStartVisible(neighbor)) {
      _chatCubit.revealTimelineItem(neighbor);
      return;
    }
    _scrollController.pageBy(_pageFraction, up: up);
  }

  void _insertNewline() {
    final text = _textController.text;
    final selection = _textController.selection;
    final start = selection.start.clamp(0, text.length);
    final end = selection.end.clamp(0, text.length);
    _textController.text =
        '${text.substring(0, start)}\n${text.substring(end)}';
    _textController.selection = TextSelection.collapsed(offset: start + 1);
  }

  /// While rewinding, the keys belong to the pick: nothing else is on offer.
  List<KeyAction> _buildRewindActions(ChatState state) => [
    KeyAction(
      label: 'Pick',
      key: LogicalKey.arrowUp,
      index: 0,
      footerOverride: '[↑/↓] Pick',
      onActivate: _chatCubit.rewindMoveUp,
    ),
    KeyAction(
      label: 'Pick',
      key: LogicalKey.arrowDown,
      visible: false,
      onActivate: _chatCubit.rewindMoveDown,
    ),
    KeyAction(
      label: 'Rewind',
      key: LogicalKey.enter,
      index: 1,
      onActivate: _chatCubit.confirmRewind,
    ),
    KeyAction(
      label: 'Cancel',
      key: LogicalKey.escape,
      index: 2,
      onActivate: _chatCubit.cancelRewind,
    ),
    ..._pageActions(state),
  ];

  List<KeyAction> _pageActions(ChatState state) => [
    KeyAction(
      label: 'Page',
      key: LogicalKey.pageUp,
      index: 2,
      footerOverride: '[PgUp/PgDn] Page',
      onActivate: () => _page(state, up: true),
    ),
    KeyAction(
      label: 'Page',
      key: LogicalKey.pageDown,
      visible: false,
      onActivate: () => _page(state, up: false),
    ),
  ];

  List<KeyAction> _buildActions({
    required ChatState state,
    required bool canCycleReasoning,
  }) {
    if (state.rewinding) return _buildRewindActions(state);
    final composer = state.composer;
    return [
      // ── Chat column ───────────────────────────────
      if (composer is WriteAccessPrompt) ...[
        KeyAction(
          label: 'Allow',
          key: LogicalKey.keyY,
          index: 0,
          onActivate: _chatCubit.allowWriteAccess,
        ),
        KeyAction(
          label: 'Deny',
          key: LogicalKey.keyN,
          index: 1,
          onActivate: _chatCubit.denyWriteAccess,
        ),
        KeyAction(
          label: 'Switch',
          key: LogicalKey.tab,
          index: 2,
          footerOverride: '[Tab] Switch',
          onActivate: _chatCubit.toggleWriteAccessChoice,
        ),
        KeyAction(
          label: 'Switch',
          key: LogicalKey.arrowLeft,
          visible: false,
          onActivate: _chatCubit.toggleWriteAccessChoice,
        ),
        KeyAction(
          label: 'Switch',
          key: LogicalKey.arrowRight,
          visible: false,
          onActivate: _chatCubit.toggleWriteAccessChoice,
        ),
        KeyAction(
          label: 'Confirm',
          key: LogicalKey.enter,
          index: 3,
          onActivate: _chatCubit.confirmWriteAccess,
        ),
      ],
      if (composer is SandboxGate && composer.acceptsEnter)
        KeyAction(
          label: 'Initialize sandbox',
          key: LogicalKey.enter,
          index: 0,
          onActivate: _chatCubit.initializeSandbox,
        ),
      if (!state.isPrimaryTurnActive && !state.loading && composer is Composing)
        KeyAction(
          label: 'Send',
          key: LogicalKey.enter,
          index: 0,
          onActivate: _sendMessage,
          visible: false,
        ),
      KeyAction(
        label: 'Newline',
        key: LogicalKey.keyN,
        ctrl: true,
        index: 1,
        visible: false,
        onActivate: _insertNewline,
      ),
      ..._pageActions(state),
      KeyAction(
        label: 'Select',
        key: LogicalKey.arrowUp,
        shift: true,
        visible: false,
        onActivate: _chatCubit.moveSelectionUp,
      ),
      KeyAction(
        label: 'Select',
        key: LogicalKey.arrowDown,
        shift: true,
        visible: false,
        onActivate: _chatCubit.moveSelectionDown,
      ),
      // ── Agent column ──────────────────────────────
      // Esc stops something when there is something to stop: the highlighted
      // subagent while the zone sits on one, otherwise the primary turn. A
      // bare Esc past that goes to the chat, where it stops background jobs
      // and, pressed twice, rewinds.
      if (state.zoneHighlightsSubagent)
        KeyAction(
          label: 'Stop',
          key: LogicalKey.escape,
          index: 0,
          onActivate: _chatCubit.stopHighlightedSubagent,
        )
      else if (state.isPrimaryTurnActive)
        KeyAction(
          label: 'Stop',
          key: LogicalKey.escape,
          index: 0,
          onActivate: _chatCubit.cancel,
        )
      else if (state.activeJobs > 0)
        KeyAction(
          label: 'Stop jobs',
          key: LogicalKey.escape,
          index: 0,
          onActivate: _chatCubit.escapePressed,
        )
      else if (state.canRewind)
        KeyAction(
          label: 'Rewind',
          key: LogicalKey.escape,
          index: 0,
          footerOverride: '[Esc Esc] Rewind',
          visible: false,
          onActivate: _chatCubit.escapePressed,
        ),
      if (canCycleReasoning)
        KeyAction(
          label: _reasoningLabel(state),
          key: LogicalKey.keyT,
          ctrl: true,
          index: 1,
          onActivate: _chatCubit.cycleReasoning,
        ),
      KeyAction(
        label: 'Clear',
        key: LogicalKey.keyR,
        ctrl: true,
        visible: false,
        index: 2,
        onActivate: _chatCubit.clear,
      ),
      // ── Subagent column (zone pseudo-focus) ───────
      // Keys are consumed first by the zone's SelectableHandler; this entry
      // is a footer hint (and a harmless fallback if the binding is absent).
      if (state.zoneActive)
        KeyAction(
          label: 'Browse',
          key: LogicalKey.arrowUp,
          footerOverride: '[↑/↓] Browse',
          index: 0,
          onActivate: _chatCubit.moveSubagentUp,
        ),
    ];
  }

  Component _buildChatList(ChatState state) {
    final timeline = state.timelineItems;
    final selectedIndex = state.effectiveSelectedIndex;
    final itemCount = timeline.isEmpty ? 1 : timeline.length;

    return ScrollableListShell(
      controller: _scrollController,
      itemCount: itemCount,
      cacheExtent: 20,
      enableSelection: true,
      onSelectionCompleted: (text) =>
          RepositoryProvider.of<OSPlatformRepository>(
            context,
          ).copyToClipboard(text),
      itemBuilder: (context, index) {
        if (timeline.isEmpty) {
          return const Center(child: Text('No messages yet.'));
        }
        final item = timeline[index];
        final isSelected = index == selectedIndex;
        final isUserMessage =
            item is MessageTimelineItem && item.role == Role.user;
        // Rewinding is a choice among the user's own messages: only those
        // answer to the mouse, the one under the pointer is boxed quietly,
        // and the chosen one is boxed in the alert color.
        final pickable = state.rewinding && isUserMessage;
        final clickable = !state.rewinding || isUserMessage;
        MessageFrame frameFor({required bool hovered}) {
          if (!pickable) return MessageFrame.none;
          if (isSelected) return MessageFrame.alert;
          return hovered ? MessageFrame.subtle : MessageFrame.none;
        }

        final row = Hoverable(
          onTap: clickable ? () => _chatCubit.selectTimelineItem(index) : null,
          builder: (context, {required hovered}) => switch (item) {
            CompactionMarkerTimelineItem() => CompactionMarkerView(
              item,
              selected: isSelected,
              hovered: hovered,
            ),
            BackgroundJobTimelineItem(:final id) ||
            JobReportTimelineItem(:final id) ||
            ToolActivityTimelineItem(:final id) => ActivityStubItemView(
              item,
              key: ValueKey(id),
              selected: isSelected,
              hovered: hovered,
            ),
            ModelCardTimelineItem(:final id, :final card) => ModelCardItem(
              key: ValueKey(id),
              card: card,
              selected: isSelected,
              hovered: hovered,
            ),
            NoticeTimelineItem(:final id, :final text) => MessageItemLayout(
              key: ValueKey(id),
              senderLabel: 'System',
              senderColor: AppTheme.of(context).highVisibility,
              selected: isSelected,
              hovered: hovered,
              content: MarkdownView(
                text,
                theme: MarkdownTheme(
                  paragraphStyle: TextStyle(
                    color: AppTheme.of(context).onBackground,
                  ),
                ),
                highlightTheme: syntaxThemeFor(AppTheme.of(context)),
              ),
            ),
            ReasoningStubTimelineItem() => ReasoningStubItemView(
              item,
              key: ValueKey(item.id),
              selected: isSelected,
              hovered: hovered,
              snippet: item.running ? state.reasoningSnippet : null,
            ),
            ToolCallDraftTimelineItem(:final id) => ToolCallDraftItemView(
              item,
              key: ValueKey(id),
              selected: isSelected,
              hovered: hovered,
            ),
            MessageTimelineItem() => MessageItem(
              key: ValueKey(item.id),
              item: item,
              selected: isSelected,
              hovered: hovered,
              frame: frameFor(hovered: hovered),
            ),
          },
        );
        // Give the answer a gap so it doesn't butt against the stub above it.
        if (_answerFollowsActivity(timeline, index)) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [const SizedBox(height: 1), row],
          );
        }
        return row;
      },
    );
  }

  /// True when [index] is an assistant answer row sitting directly beneath a
  /// one-line stub.
  bool _answerFollowsActivity(List<TimelineItem> timeline, int index) {
    if (index == 0) return false;
    final item = timeline[index];
    if (item is! MessageTimelineItem || item.role != Role.assistant) {
      return false;
    }
    final previous = timeline[index - 1];
    return previous is ActivityStubTimelineItem ||
        previous is JobReportTimelineItem;
  }

  String _reasoningLabel(ChatState state) {
    final mode = state.reasoningMode;
    final defaultEffort = state.defaultEffortLabel;
    return mode == reasoningAuto && defaultEffort != null
        ? 'Think: $mode ($defaultEffort)'
        : 'Think: $mode';
  }

  Component _buildChatBody({
    required bool showDetailsPane,
    required Component chatList,
    required Component detailsPane,
  }) {
    if (!showDetailsPane) return chatList;

    return SplitPane(
      left: chatList,
      right: detailsPane,
      minRightWidth: detailsPaneMinWidth,
    );
  }

  @override
  Component build(BuildContext context) {
    return BlocBuilder<ChatCubit, ChatState>(
      builder: (context, state) {
        final theme = AppTheme.of(context);
        final canCycleReasoning = state.canCycleReasoning;
        final actions = _buildActions(
          state: state,
          canCycleReasoning: canCycleReasoning,
        );
        return LayoutBuilder(
          builder: (context, constraints) {
            final showDetails = SplitPane.fits(constraints);
            final chatList = _buildChatList(state);
            return Container(
              color: theme.background,
              padding: const EdgeInsets.only(top: appEdgeInset),
              child: InputActions(
                actions: actions,
                child: SelectionInputHost(
                  child: Builder(
                    builder: (ctx) => Focusable(
                      focused: Provider.of<RouterContext>(
                        ctx,
                      ).focusFor(AppMode.chat),
                      onKeyEvent: (event) {
                        if (SelectionInputHost.of(ctx).tryHandle(event)) {
                          return true;
                        }
                        return InputActions.dispatch(ctx, event);
                      },
                      child: Container(
                        color: theme.background,
                        child: Column(
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: appEdgeInset,
                                ),
                                child: _buildChatBody(
                                  showDetailsPane: showDetails,
                                  chatList: chatList,
                                  detailsPane: _detailsPane,
                                ),
                              ),
                            ),
                            const Divider(),
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: 1,
                                left: appEdgeInset,
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Expanded(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        switch (state.composer) {
                                          RewindingComposer() =>
                                            const RewindHintRow(),
                                          ReadOnlyComposer() =>
                                            const SizedBox.shrink(),
                                          WriteAccessPrompt(:final request) =>
                                            WriteAccessPromptRow(
                                              request: request,
                                              choice: state.writeAccessChoice,
                                              onAllow:
                                                  _chatCubit.allowWriteAccess,
                                              onDeny:
                                                  _chatCubit.denyWriteAccess,
                                            ),
                                          SandboxGate(:final readiness) =>
                                            SandboxGateRow(
                                              readiness: readiness,
                                            ),
                                          Composing() => ChatInputRow(
                                            textController: _textController,
                                            state: state,
                                            onSubmitted: _sendMessage,
                                            onEnterZone:
                                                _chatCubit.enterSubagentZone,
                                          ),
                                        },
                                        if (state.subagents.isNotEmpty) ...[
                                          const Divider(),
                                          SubagentZoneBar(state: state),
                                          const SizedBox(height: 1),
                                        ],
                                        const PageFooter(
                                          leading: ContextIndicatorComponent(),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (showDetails)
                                    MascotStatusIndicator(
                                      key: _mascotKey,
                                      state: state,
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
