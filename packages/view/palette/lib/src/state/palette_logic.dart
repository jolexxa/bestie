import 'dart:async';

import 'package:bestie_palette_view/src/fuzzy.dart';
import 'package:bestie_palette_view/src/models/indexed_option.dart';
import 'package:bestie_palette_view/src/models/palette_row.dart';
import 'package:bestie_palette_view/src/models/pane_frame.dart';
import 'package:bestie_palette_view/src/state/options_watcher.dart';
import 'package:bestie_palette_view/src/state/palette_cubit.dart';
import 'package:bestie_palette_view/src/state/palette_data.dart';
import 'package:bestie_palette_view/src/state/palette_input.dart';
import 'package:bestie_palette_view/src/state/palette_output.dart';
import 'package:bestie_palette_view/src/state/pane_watcher.dart';
import 'package:bestie_palette_view/src/state/status_watcher.dart';
import 'package:command_protocol/command_protocol.dart';
import 'package:intentions/intentions.dart';
import 'package:logic_blocks/logic_blocks.dart';

@PartOf(PaletteCubit)
final class PaletteLogic extends LogicBlock<PaletteState> {
  PaletteLogic({required List<Command> commands}) {
    set(PaletteData(catalog: commands));
    set(OptionsWatcher(onOptions: (options) => input(OptionsLoaded(options))));
    set(
      PaneWatcher(
        onContent: (content) => input(PaneContentLoaded(content)),
        onStatus: (status) => input(PaneStatusChanged(status)),
        onFailed: (frame, error) => input(PaneStreamFailed(frame, '$error')),
      ),
    );
    set(
      StatusWatcher(
        onStatus: (command, status) =>
            input(CommandStatusChanged(command.id, status)),
      ),
    );
    set(ClosedState());
    set(BrowsingState());
    set(CollectingState());
    set(InvokingState());
    set(NavigatingPaneState());
    set(FilteringPaneState());
  }

  final List<StreamSubscription<Availability>> _availabilitySubs = [];

  @override
  void onStart() {
    for (final command in get<PaletteData>().catalog) {
      _availabilitySubs.add(
        command.availability.listen(
          (availability) =>
              input(AvailabilityChanged(command.id, availability)),
        ),
      );
    }
  }

  @override
  void onStop() {
    for (final sub in _availabilitySubs) {
      unawaited(sub.cancel());
    }
    _availabilitySubs.clear();
    get<OptionsWatcher>().watch(null);
    get<PaneWatcher>().watch(null);
    get<StatusWatcher>().stop();
  }

  @override
  Transition getInitialState() => to<ClosedState>();
}

// ── States ────────────────────────────────────────────────

@model
sealed class PaletteState extends StateLogic<PaletteState> {
  PaletteState() {
    on<AvailabilityChanged>((input) {
      data.availability[input.commandId] = input.availability;
      output(const PaletteStateUpdated());
      return toSelf();
    });
  }

  PaletteData get data => get<PaletteData>();

  /// Whether the palette overlay has content to show.
  bool get open => true;

  String get query => data.query;
  int get selectedIndex => data.selectedIndex;
  String? get error => data.error;
  String? get editError => data.editError;
  Command? get activeCommand => data.active;
  Param? get currentParam => data.currentParam;
  Set<int> get toggled => data.toggled;

  /// The breadcrumb for the open panes; empty when none are open.
  List<String> get paneTrail => data.paneTrail;

  bool get hasPanes => data.hasPanes;

  Availability availabilityOf(Command command) =>
      data.availability[command.id] ?? const Available();

  /// The catalog laid out group by group in contribution order, primary
  /// commands first within each group and unavailable ones last, keeping only
  /// the commands matching the query.
  List<PaletteRow> get rows {
    final matches = _matchingIndexes;
    final matched = [
      for (var index = 0; index < data.catalog.length; index++)
        if (matches.contains(index)) _rowOf(data.catalog[index]),
    ];
    final available = matched.where((row) => row.availability is Available);
    final unavailable = matched.where(
      (row) => row.availability is Unavailable,
    );
    final groups = <String>{for (final row in matched) row.command.group};
    return [
      for (final group in groups) ...[
        ...available.where(
          (row) =>
              row.command.group == group &&
              row.command.tier == CommandTier.primary,
        ),
        ...available.where(
          (row) =>
              row.command.group == group &&
              row.command.tier == CommandTier.normal,
        ),
        ...unavailable.where((row) => row.command.group == group),
      ],
    ];
  }

  PaletteRow _rowOf(Command command) => PaletteRow(
    command: command,
    availability: availabilityOf(command),
    status: data.statuses[command.id],
  );

  /// Catalog indexes the query matches; every index when nothing is typed.
  Set<int> get _matchingIndexes {
    if (data.query.isEmpty) {
      return {for (var index = 0; index < data.catalog.length; index++) index};
    }
    return fuzzyRank(data.query, [
      for (final command in data.catalog) '${command.group} ${command.title}',
    ], threshold: paletteMatchThreshold).toSet();
  }

  /// The first row that can actually be activated, or 0 when none can.
  int get firstAvailableIndex {
    final index = rows.indexWhere((row) => row.availability is Available);
    return index < 0 ? 0 : index;
  }

  /// The current choice param's options matching the option query, best
  /// match first, each carrying its original index.
  List<IndexedOption> get visibleOptions {
    final param = data.currentParam;
    final ranksHere =
        param is ChoiceParam &&
        param.filter is FuzzyFilter &&
        data.optionQuery.isNotEmpty;
    if (!ranksHere) {
      return [
        for (var index = 0; index < data.options.length; index++)
          IndexedOption(index: index, option: data.options[index]),
      ];
    }
    final ranked = fuzzyRank(data.optionQuery, [
      for (final option in data.options) option.keywords,
    ]);
    return [
      for (final index in ranked)
        IndexedOption(index: index, option: data.options[index]),
    ];
  }
}

@model
final class ClosedState extends PaletteState {
  ClosedState() {
    on<OpenPalette>((_) {
      data
        ..resetBrowse()
        ..selectedIndex = firstAvailableIndex;
      return to<BrowsingState>();
    });
  }

  @override
  bool get open => false;
}

/// Any state where the palette overlay is showing; hiding it (however
/// that happens) lands back on [ClosedState].
@model
sealed class OpenState extends PaletteState {
  OpenState() {
    on<ClosePalette>((_) {
      get<OptionsWatcher>().watch(null);
      get<PaneWatcher>().watch(null);
      data
        ..endFlow()
        ..endPanes();
      return to<ClosedState>();
    });
  }

  /// Starts collecting [command]'s parameters, or runs it when it has none.
  Transition beginCommand(Command command, CommandFlow flow) {
    data.beginFlow(command, flow);
    final param = flow.next(data.answers);
    if (param == null) return to<InvokingState>();
    data.prepareParam(param);
    get<OptionsWatcher>().watch(param);
    return to<CollectingState>();
  }

  /// Returns to wherever the finished flow started, the visible pane or the
  /// command list, showing [error] there.
  Transition leaveFlow({String? error}) {
    data.endFlow();
    if (!data.hasPanes) {
      data.error = error;
      return to<BrowsingState>();
    }
    data.pane.error = error;
    get<PaneWatcher>().watch(data.pane);
    return to<NavigatingPaneState>();
  }
}

/// The command list shows, each row following its command's status.
@model
final class BrowsingState extends OpenState {
  BrowsingState() {
    onEnter(() => get<StatusWatcher>().watch(data.catalog));
    onExit(() {
      get<StatusWatcher>().stop();
      data.statuses.clear();
    });
    on<CommandStatusChanged>((input) {
      switch (input.status) {
        case null:
          data.statuses.remove(input.commandId);
        case final CommandStatus status:
          data.statuses[input.commandId] = status;
      }
      output(const PaletteStateUpdated());
      return toSelf();
    });
    on<QueryChanged>((input) {
      if (input.query == data.query) return toSelf();
      data.query = input.query;
      data.error = null;
      data.selectedIndex = firstAvailableIndex;
      output(const PaletteStateUpdated());
      return toSelf();
    });
    on<MoveSelection>((input) {
      final count = rows.length;
      if (count == 0) return toSelf();
      data.selectedIndex = (data.selectedIndex + input.delta).clamp(
        0,
        count - 1,
      );
      output(CursorMoved(data.selectedIndex));
      output(const PaletteStateUpdated());
      return toSelf();
    });
    on<Activate>((_) {
      final visible = rows;
      if (visible.isEmpty) return toSelf();
      final row = visible[data.selectedIndex.clamp(0, visible.length - 1)];
      if (row.availability is Unavailable) return toSelf();
      return switch (row.command.body) {
        final CommandFlow flow => beginCommand(row.command, flow),
        CommandPane(:final pane) => _openPane(row.command, pane),
      };
    });
    on<RequestClose>((_) {
      output(const CloseRequested());
      return toSelf();
    });
  }

  Transition _openPane(Command command, Pane pane) {
    data.openPane(command, pane);
    get<PaneWatcher>().watch(data.pane);
    return to<NavigatingPaneState>();
  }
}

@model
final class CollectingState extends OpenState {
  CollectingState() {
    on<OptionsLoaded>(_onOptionsLoaded);
    on<OptionQueryChanged>((input) {
      if (input.query == data.optionQuery) return toSelf();
      data.optionQuery = input.query;
      data.selectedIndex = 0;
      get<OptionsWatcher>().query(input.query);
      output(const PaletteStateUpdated());
      return toSelf();
    });
    on<MoveSelection>((input) {
      final count = visibleOptions.length;
      if (count == 0) return toSelf();
      data.selectedIndex = (data.selectedIndex + input.delta).clamp(
        0,
        count - 1,
      );
      output(CursorMoved(data.selectedIndex));
      output(const PaletteStateUpdated());
      return toSelf();
    });
    on<ToggleOption>(_onToggleOption);
    on<SubmitText>(_onSubmitText);
    on<SubmitChoice>(_onSubmitChoice);
    on<Back>(_onBack);
  }

  Transition _onOptionsLoaded(OptionsLoaded input) {
    data.options = input.options;
    final count = visibleOptions.length;
    if (count > 0 && data.selectedIndex >= count) {
      data.selectedIndex = count - 1;
    }
    output(const PaletteStateUpdated());
    return toSelf();
  }

  Transition _onToggleOption(ToggleOption input) {
    if (data.currentParam is! MultiChoiceParam) return toSelf();
    final visible = visibleOptions;
    if (visible.isEmpty) return toSelf();
    final original =
        visible[data.selectedIndex.clamp(0, visible.length - 1)].index;
    if (!data.toggled.add(original)) data.toggled.remove(original);
    output(const PaletteStateUpdated());
    return toSelf();
  }

  Transition _onSubmitText(SubmitText input) {
    final text = input.text.trim();
    switch (data.currentParam) {
      case final TextParam param:
        final problem = param.validate?.call(input.text);
        if (problem != null) return _reject(problem);
        data.answers = data.answers.put(param.key, input.text);
        return _advance();
      case final NumberParam<int> param:
        return _submitNumber(param, int.tryParse(text));
      case final NumberParam<double> param:
        return _submitNumber(param, double.tryParse(text));
      case final NumberParam param:
        return _submitNumber(param, num.tryParse(text));
      case _:
        return toSelf();
    }
  }

  Transition _submitNumber<T extends num>(NumberParam<T> param, T? value) {
    if (value == null) return _reject('Enter a number');
    final min = param.min;
    if (min != null && value < min) return _reject('Must be at least $min');
    final max = param.max;
    if (max != null && value > max) return _reject('Must be at most $max');
    data.answers = data.answers.put(param.key, value);
    return _advance();
  }

  Transition _onSubmitChoice(SubmitChoice input) {
    switch (data.currentParam) {
      case final ConfirmParam param:
        data.answers = data.answers.put(param.key, true);
        return _advance();
      case final ChoiceParam<Object?> param:
        final visible = visibleOptions;
        if (visible.isEmpty) return toSelf();
        final option =
            visible[data.selectedIndex.clamp(0, visible.length - 1)].option;
        data.answers = data.answers.put(param.key, option.value);
        return _advance();
      case final MultiChoiceParam<Object?> param:
        final count = data.toggled.length;
        final min = param.min;
        if (min != null && count < min) {
          return _reject('Pick at least $min');
        }
        final max = param.max;
        if (max != null && count > max) {
          return _reject('Pick at most $max');
        }
        final indexes = data.toggled.toList()..sort();
        data.answers = data.answers.put(
          param.key,
          param.answerFor(data.options, indexes),
        );
        return _advance();
      case _:
        return toSelf();
    }
  }

  Transition _onBack(Back input) {
    final watcher = get<OptionsWatcher>();
    if (data.answers.isEmpty) {
      watcher.watch(null);
      return leaveFlow();
    }
    data.answers = data.answers.pop();
    final param = data.flow!.next(data.answers);
    if (param == null) {
      watcher.watch(null);
      return to<InvokingState>();
    }
    data.prepareParam(param);
    watcher.watch(param);
    output(const PaletteStateUpdated());
    return toSelf();
  }

  Transition _reject(String problem) {
    data.editError = problem;
    output(const PaletteStateUpdated());
    return toSelf();
  }

  Transition _advance() {
    data.editError = null;
    final param = data.flow!.next(data.answers);
    final watcher = get<OptionsWatcher>();
    if (param == null) {
      watcher.watch(null);
      return to<InvokingState>();
    }
    data.prepareParam(param);
    watcher.watch(param);
    output(const PaletteStateUpdated());
    return toSelf();
  }
}

@model
final class InvokingState extends OpenState {
  InvokingState() {
    onEnter(() {
      async(data.flow!.invoke(data.answers))
          .input(InvokeSettled.new)
          .errorInput((error) => InvokeSettled(CommandRejected('$error')));
    });
    on<InvokeSettled>((input) {
      switch (input.result) {
        case CommandRan():
          if (!data.hasPanes) output(const CloseRequested());
          return leaveFlow();
        case CommandRejected(:final reason):
          return leaveFlow(error: reason);
      }
    });
  }

  /// What to show while the command runs.
  String? get running => data.flow?.running;
}

/// A pane is showing: its breadcrumb, query, status band and rows.
@model
sealed class ViewingPaneState extends OpenState {
  ViewingPaneState() {
    on<PaneContentLoaded>((input) {
      frame.show(input.content);
      return _updated();
    });
    on<PaneStatusChanged>((input) {
      frame.status = input.status;
      return _updated();
    });
    on<PaneStreamFailed>((input) {
      input.frame.error = input.reason;
      return _updated();
    });
    on<QueryChanged>((input) {
      if (input.query == frame.query) return toSelf();
      frame
        ..search(input.query)
        ..error = null;
      get<PaneWatcher>().query(frame);
      return _land<FilteringPaneState>();
    });
    on<MoveSelection>((input) {
      frame.select(frame.selectedIndex + input.delta);
      output(CursorMoved(frame.selectedIndex));
      return _land<NavigatingPaneState>();
    });
    on<Activate>((_) => runKey(const PrimaryKey()));
    on<Back>((_) => _pop());
    on<PaneActionSettled>((input) {
      if (!identical(input.frame, frame)) return toSelf();
      frame.pendingAction = null;
      return _settle(input.result);
    });
  }

  /// The printable key that hands the keyboard to the query field when the
  /// row's own actions would otherwise claim what is typed.
  static const filterKey = '/';

  PaneFrame get frame => data.pane;

  Pane get pane => frame.pane;

  @override
  String get query => frame.query;

  @override
  int get selectedIndex => frame.selectedIndex;

  @override
  String? get error => frame.error;

  PaneStatus? get status => frame.status;

  /// The action still running, if any; other actions wait for it.
  PaneAction? get pendingAction => frame.pendingAction;

  /// Whether the pane has yet to list anything.
  bool get loading => frame.content == null;

  /// Whether the pane takes a typed query.
  bool get hasQuery => pane.filter != PaneFilter.none;

  /// The pane's sections narrowed to the rows matching the query when the
  /// palette does the filtering, keeping section and row order.
  List<PaneSection> get visibleSections => frame.visibleSections;

  /// Every visible row in listing order.
  List<PaneRow> get visibleRows => frame.visibleRows;

  PaneRow? get selectedRow => frame.selectedRow;

  /// The selected row's actions a key press can run right now.
  List<PaneAction> get liveActions;

  /// The band's actions a key press can run right now.
  List<PaneAction> get bandActions;

  /// Whether the footer should offer [filterKey].
  bool get offersFilterKey;

  /// Whether a press of [char] belongs to the pane rather than to the query
  /// field.
  bool claimsKey(String char);

  /// What [key] runs: the selected row's action for it, else the band's.
  PaneAction? actionFor(PaneKey key) =>
      selectedRow?.actionFor(key) ?? bandActions.forKey(key);

  /// Runs the action for [key], when there is one.
  Transition runKey(PaneKey key) => switch (actionFor(key)) {
    null => toSelf(),
    final PaneAction action => _run(action),
  };

  Transition _run(PaneAction action) {
    if (frame.pendingAction != null) return toSelf();
    final running = frame
      ..pendingAction = action
      ..error = null;
    async(action.invoke())
        .input((result) => PaneActionSettled(running, result))
        .errorInput(
          (error) => PaneActionSettled(running, PaneRejected('$error')),
        );
    return _updated();
  }

  Transition _settle(PaneActionResult result) => switch (result) {
    PaneStay() => _updated(),
    PaneClose() => _close(),
    PanePop() => _pop(),
    PaneRejected(:final reason) => _reject(reason),
    PanePush(:final pane) => _push(pane),
    PaneOpenCommand(:final command) => _openCommand(command),
  };

  Transition _close() {
    get<PaneWatcher>().watch(null);
    data.endPanes();
    output(const CloseRequested());
    return to<BrowsingState>();
  }

  Transition _reject(String reason) {
    frame.error = reason;
    return _updated();
  }

  Transition _push(Pane pane) {
    data.panes.add(PaneFrame(pane));
    get<PaneWatcher>().watch(data.pane);
    output(const CursorMoved(0));
    return _land<NavigatingPaneState>();
  }

  Transition _openCommand(Command command) => switch (command.body) {
    final CommandFlow flow => _beginFlow(command, flow),
    CommandPane(:final pane) => _push(pane),
  };

  Transition _beginFlow(Command command, CommandFlow flow) {
    get<PaneWatcher>().watch(null);
    frame.error = null;
    return beginCommand(command, flow);
  }

  Transition _pop() {
    final watcher = get<PaneWatcher>();
    data.panes.removeLast();
    if (!data.hasPanes) {
      watcher.watch(null);
      data.endPanes();
      return to<BrowsingState>();
    }
    data.pane.error = null;
    watcher.watch(data.pane);
    output(CursorMoved(data.pane.selectedIndex));
    return _land<NavigatingPaneState>();
  }

  /// Moves to [T], announcing the update when the palette is already there.
  Transition _land<T extends ViewingPaneState>() {
    if (this is T) output(const PaletteStateUpdated());
    return to<T>();
  }

  Transition _updated() {
    output(const PaletteStateUpdated());
    return toSelf();
  }
}

/// The pane's list has the keyboard: printable keys bound to the selected
/// row or the band run their actions, and any other typing goes to the
/// query.
@model
final class NavigatingPaneState extends ViewingPaneState {
  NavigatingPaneState() {
    on<PaneKeyPressed>((input) {
      final key = CharKey(input.char);
      if (actionFor(key) != null) return runKey(key);
      if (!claimsKey(input.char)) return toSelf();
      return to<FilteringPaneState>();
    });
  }

  @override
  List<PaneAction> get liveActions => selectedRow?.actions ?? const [];

  @override
  List<PaneAction> get bandActions => status?.actions ?? const [];

  @override
  bool get offersFilterKey =>
      hasQuery &&
      [...liveActions, ...bandActions].any((action) => !action.primary);

  @override
  bool claimsKey(String char) =>
      actionFor(CharKey(char)) != null ||
      (hasQuery && char == ViewingPaneState.filterKey);
}

/// The pane's query field has the keyboard: everything printable is typed,
/// and only Enter runs the selected row's action.
@model
final class FilteringPaneState extends ViewingPaneState {
  @override
  List<PaneAction> get liveActions => [
    ?selectedRow?.actionFor(const PrimaryKey()),
  ];

  @override
  List<PaneAction> get bandActions => const [];

  @override
  bool get offersFilterKey => false;

  @override
  bool claimsKey(String char) => false;
}
