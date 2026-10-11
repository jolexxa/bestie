import 'package:config_protocol/src/config_key.dart';

/// Declarative description of one config-overlay page.
sealed class ConfigPage {
  const ConfigPage({required this.id, required this.label});

  /// Stable identifier.
  final String id;

  /// User-visible label.
  final String label;
}

/// Page composed of one or more [ConfigSection]s.
final class ConfigParamPage extends ConfigPage {
  const ConfigParamPage({
    required super.id,
    required super.label,
    required this.sections,
  });

  final List<ConfigSection> sections;

  /// Every address on the page, in section order.
  Iterable<ConfigAddressBase> get addresses =>
      sections.expand((section) => section.addresses);
}

/// Page whose content is owned by the feature renderer, keyed by [id].
sealed class ConfigCustomPage extends ConfigPage {
  const ConfigCustomPage({required super.id, required super.label});
}

/// A read-only, informative page: a list of feature-defined rows the user can
/// arrow through.
final class ConfigInfoPage extends ConfigCustomPage {
  const ConfigInfoPage({
    required super.id,
    required super.label,
    required this.rowCount,
    required this.visualIndex,
  });

  /// Number of arrow-navigable rows for a given `entryCount`.
  final int Function(int entryCount) rowCount;

  /// Maps a selected `rowIndex` to its position in the rendered visual
  /// list for scroll-into-view.
  final int Function(int rowIndex, int entryCount) visualIndex;
}

/// A page rendered as a single scrollable document.
final class ConfigDocumentPage extends ConfigCustomPage {
  const ConfigDocumentPage({required super.id, required super.label});
}

/// One section on a [ConfigParamPage]: the settings it shows, in order.
final class ConfigSection {
  const ConfigSection({required this.heading, required this.addresses});

  final String heading;
  final List<ConfigAddressBase> addresses;
}

/// The full data-driven description of the app's config overlay.
final class ConfigLayout {
  const ConfigLayout({required this.pages, required this.initialPageId});

  /// Ordered list of pages (cycle order in the overlay).
  final List<ConfigPage> pages;

  /// Id of the page selected when the overlay first opens. Must match
  /// one of [pages]; consumers clamp to this when an unknown id is
  /// encountered.
  final String initialPageId;

  /// Lookup by id; returns `null` if no such page.
  ConfigPage? pageById(String id) =>
      pages.where((page) => page.id == id).firstOrNull;
}
