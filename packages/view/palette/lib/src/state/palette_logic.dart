import 'dart:async';

import 'package:bestie_palette_view/src/fuzzy.dart';
import 'package:bestie_palette_view/src/models/indexed_option.dart';
import 'package:bestie_palette_view/src/models/palette_row.dart';
import 'package:bestie_palette_view/src/state/options_watcher.dart';
import 'package:bestie_palette_view/src/state/palette_cubit.dart';
import 'package:bestie_palette_view/src/state/palette_data.dart';
import 'package:bestie_palette_view/src/state/palette_input.dart';
import 'package:bestie_palette_view/src/state/palette_output.dart';
import 'package:command_protocol/command_protocol.dart';
import 'package:intentions/intentions.dart';
import 'package:logic_blocks/logic_blocks.dart';

@PartOf(PaletteCubit)
final class PaletteLogic extends LogicBlock<PaletteState> {
  PaletteLogic({required List<Command> commands}) {
    set(PaletteData(catalog: commands));
    set(OptionsWatcher(onOptions: (options) => input(OptionsLoaded(options))));
    set(ClosedState());
    set(BrowsingState());
    set(CollectingState());
    set(InvokingState());
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

  static const _matchThreshold = 0.4;

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

  Availability availabilityOf(Command command) =>
      data.availability[command.id] ?? const Available();

  /// The catalog laid out group by group in contribution order, primary
  /// commands first within each group and unavailable ones last, keeping only
  /// the commands matching the query.
  List<PaletteRow> get rows {
    final matches = _matchingIndexes;
    final matched = [
      for (var index = 0; index < data.catalog.length; index++)
        if (matches.contains(index))
          PaletteRow(
            command: data.catalog[index],
            availability: availabilityOf(data.catalog[index]),
          ),
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

  /// Catalog indexes the query matches; every index when nothing is typed.
  Set<int> get _matchingIndexes {
    if (data.query.isEmpty) {
      return {for (var index = 0; index < data.catalog.length; index++) index};
    }
    return fuzzyRank(data.query, [
      for (final command in data.catalog) '${command.group} ${command.title}',
    ], threshold: _matchThreshold).toSet();
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
        for (var i = 0; i < data.options.length; i++)
          IndexedOption(index: i, option: data.options[i]),
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
    onEnter(() => output(const PaletteStateUpdated()));
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
      data.endFlow();
      return to<ClosedState>();
    });
  }
}

@model
final class BrowsingState extends OpenState {
  BrowsingState() {
    onEnter(() => output(const PaletteStateUpdated()));
    on<QueryChanged>((input) {
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
      data.beginFlow(row.command);
      final param = row.command.next(data.answers);
      if (param == null) return to<InvokingState>();
      data.prepareParam(param);
      get<OptionsWatcher>().watch(param);
      return to<CollectingState>();
    });
    on<RequestClose>((_) {
      output(const CloseRequested());
      return toSelf();
    });
  }
}

@model
final class CollectingState extends OpenState {
  CollectingState() {
    onEnter(() => output(const PaletteStateUpdated()));
    on<OptionsLoaded>(_onOptionsLoaded);
    on<OptionQueryChanged>((input) {
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
      data.endFlow();
      return to<BrowsingState>();
    }
    data.answers = data.answers.pop();
    final param = data.active!.next(data.answers);
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
    final param = data.active!.next(data.answers);
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
      output(const PaletteStateUpdated());
      async(data.active!.invoke(data.answers))
          .input(InvokeSettled.new)
          .errorInput((error) => InvokeSettled(CommandRejected('$error')));
    });
    on<InvokeSettled>((input) {
      switch (input.result) {
        case CommandRan():
          data.endFlow();
          output(const CloseRequested());
          return to<BrowsingState>();
        case CommandRejected(:final reason):
          data
            ..endFlow()
            ..error = reason;
          return to<BrowsingState>();
      }
    });
  }

  /// What to show while the command runs.
  String? get running => data.active?.running;
}
