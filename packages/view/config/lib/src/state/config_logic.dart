import 'dart:async';

import 'package:bestie_config_use_case/bestie_config_use_case.dart';
import 'package:bestie_config_view/src/state/config_cubit.dart';
import 'package:bestie_config_view/src/state/config_data.dart';
import 'package:bestie_config_view/src/state/config_input.dart';
import 'package:bestie_config_view/src/state/config_output.dart';
import 'package:intentions/intentions.dart';
import 'package:logic_blocks/logic_blocks.dart';

@PartOf(ConfigCubit)
final class ConfigLogic extends LogicBlock<ConfigState> {
  ConfigLogic({
    required ConfigUseCase configUseCase,
    required ConfigLayout layout,
  }) {
    set(configUseCase);
    set(layout);
    set(ConfigData(selectedPageId: layout.initialPageId));
    set(BrowsingState());
    set(EditingState());
  }

  StreamSubscription<ConfigChange>? _configSub;

  @override
  Transition getInitialState() => to<BrowsingState>();

  @override
  void onStart() {
    _configSub = get<ConfigUseCase>().changes.listen(
      (_) => input(const ConfigChanged()),
    );
  }

  @override
  void onStop() {
    unawaited(_configSub?.cancel());
    _configSub = null;
  }
}

// ── States ────────────────────────────────────────────────

@model
sealed class ConfigState extends StateLogic<ConfigState> {
  ConfigData get data => get<ConfigData>();
  ConfigUseCase get configUseCase => get<ConfigUseCase>();
  ConfigLayout get layout => get<ConfigLayout>();

  /// The resolved page for the currently selected id, or null if the
  /// id has drifted (defensive — shouldn't happen in practice).
  ConfigPage? get selectedPage => layout.pageById(data.selectedPageId);

  int get selectedIndex => data.selectedIndex;
  String? get editError => data.editError;
  bool get hasTargetScope => data.targetScope != null;

  /// All entries on the currently selected page. Empty for custom
  /// pages (Info) and for unknown ids.
  List<ConfigEntry> get visibleEntries => switch (selectedPage) {
    ConfigParamPage(:final sections) =>
      sections.expand((s) => s.entries).toList(),
    _ => const [],
  };

  /// Currently highlighted entry, or null if no entries on this page.
  ConfigEntry? get selectedEntry {
    final entries = visibleEntries;
    if (entries.isEmpty) return null;
    return entries[data.selectedIndex.clamp(0, entries.length - 1)];
  }

  ConfigAddressBase? addressFor(ConfigEntry entry) =>
      entry.addressFor(targetScope: data.targetScope);

  Object? editStartValueFor(
    ConfigEntry entry,
    ConfigAddressBase address,
  ) => configUseCase.resolveBase(address);

  bool hasUserValue(ConfigAddressBase address) =>
      configUseCase.isExplicitBase(address);

  bool applyAdjust(
    ConfigEntry entry,
    ConfigAddressBase address,
    int delta,
  ) {
    final current = configUseCase.resolveBase(address);
    final next = entry.field.adjustValue(current, delta);
    if (next == current) return false;
    configUseCase.updateBase(address, ConfigEditBase.set(next));
    return true;
  }

  String? applyText(ConfigEntry entry, String text) {
    final address = addressFor(entry);
    if (address == null) return 'No target selected';
    final parsed = entry.field.parseValue(text);
    if (parsed == null) return 'Invalid value';
    final validation = entry.field.validateValue(parsed);
    if (validation is Invalid) return validation.message;
    configUseCase.updateBase(address, ConfigEditBase.set(parsed));
    return null;
  }

  /// Whether the state is currently in text-editing mode.
  bool get editing => false;

  /// Max valid `selectedIndex` for the current page, or -1 when
  /// nothing on the page is selectable.
  int get selectionMax => switch (selectedPage) {
    ConfigParamPage(:final sections) =>
      sections.expand((s) => s.entries).length - 1,
    ConfigInfoPage(:final rowCount) => rowCount(data.toolCount) - 1,
    ConfigDocumentPage() => -1,
    null => -1,
  };
}

@model
final class BrowsingState extends ConfigState {
  BrowsingState() {
    on<Initialize>((input) {
      data.targetScope = input.targetScope;
      data.toolCount = input.toolCount;
      output(const ConfigStateUpdated());
      return toSelf();
    });

    on<MoveSelection>((input) {
      final max = selectionMax;
      if (max < 0) return toSelf();
      final previous = data.selectedIndex;
      final next = (previous + input.delta).clamp(0, max);
      data.selectedIndex = next;
      output(const ConfigStateUpdated());
      if (next != previous) output(CursorMoved(next));
      return toSelf();
    });

    on<ChangePage>((input) {
      final ids = layout.pages.map((p) => p.id).toList();
      final i = ids.indexOf(data.selectedPageId);
      final base = i == -1 ? 0 : i;
      data.selectedPageId = ids[(base + input.delta) % ids.length];
      data.selectedIndex = 0;
      output(const ConfigStateUpdated());
      output(const PageChanged());
      return toSelf();
    });

    on<InlineAdjust>((input) {
      final entry = selectedEntry;
      if (entry == null) return toSelf();
      final address = addressFor(entry);
      if (address == null) return toSelf();
      final adjusted = applyAdjust(entry, address, input.delta);
      if (!adjusted) return toSelf();
      output(const ConfigStateUpdated());
      return toSelf();
    });

    on<BeginEdit>((input) {
      final entry = selectedEntry;
      if (entry == null) return toSelf();
      final address = addressFor(entry);
      if (address == null) return toSelf();
      return to<EditingState>();
    });

    on<ResetParam>((_) {
      final entry = selectedEntry;
      if (entry == null) return toSelf();
      final address = addressFor(entry);
      if (address == null) return toSelf();
      if (!hasUserValue(address)) return toSelf();
      configUseCase.updateBase(address, const ConfigEditBase.clear());
      output(const ConfigStateUpdated());
      return toSelf();
    });

    on<RequestClose>((_) {
      output(const CloseRequested());
      return toSelf();
    });

    on<ConfigChanged>((_) {
      output(const ConfigStateUpdated());
      return toSelf();
    });
  }
}

@model
final class EditingState extends ConfigState {
  EditingState() {
    onEnter(() => output(const ConfigStateUpdated()));

    on<ConfirmEdit>((input) {
      final entry = selectedEntry;
      if (entry == null) return toSelf();
      final error = applyText(entry, input.text);
      if (error == null) {
        data.editError = null;
        return to<BrowsingState>();
      }
      data.editError = error;
      output(const ConfigStateUpdated());
      return toSelf();
    });

    on<CancelEdit>((_) {
      data.editError = null;
      return to<BrowsingState>();
    });

    on<ChangePage>((input) {
      data.editError = null;
      final ids = layout.pages.map((p) => p.id).toList();
      final i = ids.indexOf(data.selectedPageId);
      final base = i == -1 ? 0 : i;
      data.selectedPageId = ids[(base + input.delta) % ids.length];
      data.selectedIndex = 0;
      output(const PageChanged());
      return to<BrowsingState>();
    });

    on<RequestClose>((_) {
      data.editError = null;
      return to<BrowsingState>();
    });

    on<ConfigChanged>((_) {
      output(const ConfigStateUpdated());
      return toSelf();
    });
  }

  @override
  bool get editing => true;
}
