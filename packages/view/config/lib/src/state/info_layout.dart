/// Canonical structure of the Info page.
///
/// The Info page is read-only (no editable params), so unlike the other
/// config pages it can't derive its row count from the key schema.
/// Instead, [infoLayout] returns the explicit ordered list of entries
/// that defines the page; rendering, selectable-row counting, and
/// arrow-key scroll mapping all walk that same list.
///
/// Adding or reordering an entry requires editing [infoLayout] only.
library;

import 'package:intentions/intentions.dart';

/// One entry in the Info page's flat visual list.
@model
sealed class InfoEntry {
  const InfoEntry();

  /// Whether this entry participates in arrow-key navigation.
  bool get selectable;
}

/// A section heading (e.g. "System", "Paths"). Not selectable.
@model
final class InfoHeader extends InfoEntry {
  const InfoHeader(this.label);
  final String label;
  @override
  bool get selectable => false;
}

/// The `*required` legend shown above the tool list. Not selectable.
@model
final class InfoLegend extends InfoEntry {
  const InfoLegend();
  @override
  bool get selectable => false;
}

/// A selectable row. [kind] disambiguates which content to render.
@model
final class InfoRow extends InfoEntry {
  const InfoRow(this.kind, {this.toolIndex});

  final InfoRowKind kind;

  /// Only set when [kind] is [InfoRowKind.tool].
  final int? toolIndex;

  @override
  bool get selectable => true;
}

/// Discriminator for [InfoRow] content.
@model
enum InfoRowKind {
  version,
  description,
  platform,
  provider,
  credits,
  configPath,
  tool,
}

/// The canonical entry list for the Info page.
List<InfoEntry> infoLayout({required int toolCount}) {
  return [
    const InfoRow(InfoRowKind.version),
    const InfoRow(InfoRowKind.description),
    const InfoRow(InfoRowKind.platform),
    const InfoHeader('Provider'),
    const InfoRow(InfoRowKind.provider),
    const InfoRow(InfoRowKind.credits),
    const InfoHeader('Paths'),
    const InfoRow(InfoRowKind.configPath),
    if (toolCount > 0) ...[
      const InfoHeader('Tools'),
      const InfoLegend(),
      for (var i = 0; i < toolCount; i++)
        InfoRow(InfoRowKind.tool, toolIndex: i),
    ],
  ];
}

/// Number of selectable rows on the Info page for a given [toolCount].
/// Used by the cubit to clamp arrow-key navigation.
int infoSelectableCount({required int toolCount}) =>
    infoLayout(toolCount: toolCount).where((e) => e.selectable).length;

/// Visual-list index of the [selectionIndex]-th selectable entry, used
/// to scroll the focused row into view on arrow-key navigation.
int infoVisualIndexFor(int selectionIndex, {required int toolCount}) =>
    infoLayout(
      toolCount: toolCount,
    ).indexed.where((pair) => pair.$2.selectable).elementAt(selectionIndex).$1;
