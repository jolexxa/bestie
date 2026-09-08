import 'package:config_protocol/src/config_entry.dart';

/// Declarative description of one config-overlay page.
sealed class ConfigPage {
  const ConfigPage({
    required this.id,
    required this.label,
    this.requiresTargetScope = false,
  });

  /// Stable identifier — used by the cubit's `selectedPageId` carrier
  /// and as the key the view dispatches on for custom pages.
  final String id;

  /// User-visible label for the left-pane page list.
  final String label;

  /// When `true`, the page can only be selected/edited if the host has
  /// a scoped config target.
  final bool requiresTargetScope;
}

/// Page composed of one or more [ConfigSection]s.
final class ConfigParamPage extends ConfigPage {
  const ConfigParamPage({
    required super.id,
    required super.label,
    required this.sections,
    super.requiresTargetScope,
  });

  final List<ConfigSection> sections;

  /// All entries on the page, in section order.
  Iterable<ConfigEntry> get entries => sections.expand((s) => s.entries);
}

/// Page whose content is owned by the feature renderer, keyed by [id].
sealed class ConfigCustomPage extends ConfigPage {
  const ConfigCustomPage({
    required super.id,
    required super.label,
    super.requiresTargetScope,
  });
}

/// A read-only, informative page: a list of feature-defined rows the user can
/// arrow through.
final class ConfigInfoPage extends ConfigCustomPage {
  const ConfigInfoPage({
    required super.id,
    required super.label,
    required this.rowCount,
    required this.visualIndex,
    super.requiresTargetScope,
  });

  /// Number of arrow-navigable rows for a given `entryCount`.
  final int Function(int entryCount) rowCount;

  /// Maps a selected `rowIndex` to its position in the rendered visual
  /// list for scroll-into-view.
  final int Function(int rowIndex, int entryCount) visualIndex;
}

/// A page rendered as a single scrollable document.
final class ConfigDocumentPage extends ConfigCustomPage {
  const ConfigDocumentPage({
    required super.id,
    required super.label,
    super.requiresTargetScope,
  });
}

/// One section on a [ConfigParamPage].
final class ConfigSection {
  const ConfigSection({
    required this.heading,
    required this.entries,
  });

  final String heading;
  final List<ConfigEntry> entries;
}

/// The full data-driven description of the app's config overlay.
///
/// Holds the ordered list of [ConfigPage]s shown in the overlay
/// plus any [orphanEntries] that the schema must still persist but
/// no page surfaces (today: `assignment` — owned UI-wise by the
/// Models page, not the config overlay).
final class ConfigLayout {
  const ConfigLayout({
    required this.pages,
    required this.initialPageId,
    this.orphanEntries = const [],
  });

  /// Ordered list of pages (cycle order in the overlay).
  final List<ConfigPage> pages;

  /// Id of the page selected when the overlay first opens. Must match
  /// one of [pages]; consumers clamp to this when an unknown id is
  /// encountered.
  final String initialPageId;

  /// Entries not surfaced on any page. Still flattened into the schema
  /// so the repository can resolve and persist them.
  final List<ConfigEntry> orphanEntries;

  /// All entries (page + orphan), useful for layout-level traversal.
  Iterable<ConfigEntry> get allEntries sync* {
    for (final p in pages.whereType<ConfigParamPage>()) {
      yield* p.entries;
    }
    yield* orphanEntries;
  }

  /// Look up an entry by its key id.
  ConfigEntry? entryByKey(String key) {
    for (final e in allEntries) {
      if (e.key.id == key) return e;
    }
    return null;
  }

  /// Lookup by id; returns `null` if no such page.
  ConfigPage? pageById(String id) => pages.where((p) => p.id == id).firstOrNull;
}
