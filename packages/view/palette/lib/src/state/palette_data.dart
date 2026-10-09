import 'package:bestie_palette_view/src/models/pane_frame.dart';
import 'package:command_protocol/command_protocol.dart';
import 'package:intentions/intentions.dart';

/// Shared mutable state for the palette state machine.
@model
final class PaletteData {
  PaletteData({required this.catalog});

  /// Every command the palette can offer, in contribution order.
  final List<Command> catalog;

  /// Latest availability observed per command id; absent means available.
  final Map<String, Availability> availability = {};

  /// Latest status reported per command id while the command list shows;
  /// absent means nothing to report.
  final Map<String, CommandStatus> statuses = {};

  String query = '';
  int selectedIndex = 0;

  /// Rejection reason from the last command run from the command list,
  /// surfaced in its header band.
  String? error;

  /// Open panes, the visible one last.
  final List<PaneFrame> panes = [];

  /// The command that opened the first pane; null when no pane is open.
  Command? paneOrigin;

  Command? active;
  CommandFlow? flow;
  Param? currentParam;
  Answers answers = const Answers.empty();
  List<Option<Object?>> options = const [];
  String optionQuery = '';
  final Set<int> toggled = {};

  /// Validation problem for the value currently being collected.
  String? editError;

  void resetBrowse() {
    query = '';
    selectedIndex = 0;
    error = null;
  }

  void beginFlow(Command command, CommandFlow commandFlow) {
    active = command;
    flow = commandFlow;
    answers = const Answers.empty();
    error = null;
  }

  void prepareParam(Param param) {
    currentParam = param;
    options = const [];
    optionQuery = '';
    toggled.clear();
    selectedIndex = 0;
    editError = null;
  }

  bool get hasPanes => panes.isNotEmpty;

  /// The breadcrumb for the open panes, led by the opening command's group;
  /// empty when none are open.
  List<String> get paneTrail => [
    ?paneOrigin?.group,
    for (final frame in panes) frame.pane.title,
  ];

  /// The visible pane.
  PaneFrame get pane => panes.last;

  void openPane(Command command, Pane pane) {
    paneOrigin = command;
    panes
      ..clear()
      ..add(PaneFrame(pane));
    error = null;
  }

  void endPanes() {
    panes.clear();
    paneOrigin = null;
  }

  void endFlow() {
    active = null;
    flow = null;
    currentParam = null;
    answers = const Answers.empty();
    options = const [];
    optionQuery = '';
    toggled.clear();
    editError = null;
  }
}
