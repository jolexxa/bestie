import 'package:bestie_ui/bestie_ui.dart';
import 'package:intentions/intentions.dart';
import 'package:tool_protocol/tool_protocol.dart' show FileDiff;

/// How prominently a value reads. The mapping is a pure function dealing in
/// meaning, not color — so the chat stub and this pane agree without coupling.
@model
enum DetailAccent {
  /// Ordinary content.
  normal,

  /// Present but secondary — timings, ids, prose the user is skimming.
  muted,

  /// Went wrong.
  error,

  /// Finished, and finished well.
  success,

  /// In flight.
  running,

  /// Worth the eye landing on it first.
  emphasis,
}

/// Who a row's content came from.
@model
enum Provenance {
  /// The user typed it.
  you,

  /// The model produced it.
  model,

  /// A tool the model called produced it.
  tool,

  /// The harness synthesized it — a job report, notice, model card, compaction.
  harness,
}

/// The two faces of a selected item, each its own pinned tab in the workspace.
@model
enum DetailsTab {
  /// Inputs behind the row — arguments, stats, model facts. The `{ }` tab.
  properties,

  /// What the row output — text, reasoning, links, a terminal. The Details tab.
  details,
}

/// One reading on the measurement strip. [value] is null until known, but the
/// slot is still drawn as `— t/s` so a later number fills a hole, not shifts.
@model
final class Measurement {
  const Measurement({required this.value, this.unit = ''})
    : runningSince = null;

  /// A slot still counting: it reads how long since [runningSince].
  const Measurement.running(DateTime this.runningSince)
    : value = null,
      unit = '';

  final String? value;
  final String unit;
  final DateTime? runningSince;

  /// What the strip draws for this slot as of [now].
  String displayAt(DateTime now) {
    final since = runningSince;
    final shown = since != null
        ? now.difference(since).inMilliseconds.asDuration
        : (value ?? '—');
    return unit.isEmpty ? shown : '$shown $unit';
  }
}

/// One label/value pair in a facts table.
@model
final class DetailFact {
  const DetailFact(this.label, this.value, {this.accent = DetailAccent.normal});

  final String label;
  final String value;
  final DetailAccent accent;
}

/// A link out of the app.
@model
final class DetailLink {
  const DetailLink({required this.url, this.title});

  final String url;
  final String? title;
}

/// One block of a details pane, named for how it reads, not what produced it —
/// so the pane lays out sections while something else fills the live ones.
@model
sealed class DetailSection {
  const DetailSection();
}

/// A table of label/value pairs.
@model
final class FactsSection extends DetailSection {
  const FactsSection(this.facts);

  final List<DetailFact> facts;
}

/// A run of prose or markdown under an optional heading.
@model
final class TextSection extends DetailSection {
  const TextSection(
    this.text, {
    this.label,
    this.accent = DetailAccent.normal,
    this.streaming = false,
  });

  final String text;
  final String? label;
  final DetailAccent accent;

  /// True while the text is still being appended to.
  final bool streaming;
}

/// A list of links.
@model
final class LinksSection extends DetailSection {
  const LinksSection(this.links, {this.label = 'Sources'});

  final List<DetailLink> links;
  final String label;
}

/// A change to the file at [path], drawn as unified-diff hunks.
@model
final class DiffSection extends DetailSection {
  const DiffSection(this.diff, {required this.path});

  final FileDiff diff;
  final String path;
}

/// The file a call made at [path], drawn as its text. [lines] counts the
/// whole file even when [truncated] cut [text] short.
@model
final class CreatedFileSection extends DetailSection {
  const CreatedFileSection(
    this.text, {
    required this.path,
    required this.lines,
    this.truncated = false,
  });

  final String text;
  final String path;
  final int lines;
  final bool truncated;
}

/// A live body addressed by [key], mounted by whoever renders the pane — today
/// a tool call's shell. [fallback] fills the slot when the key names nothing.
@model
final class LiveSection extends DetailSection {
  const LiveSection(this.key, {this.label, this.fallback});

  final String key;
  final String? label;

  /// Drawn in place of the live body when there is none.
  final DetailSection? fallback;
}

/// Everything the details pane draws for one selected timeline item.
@model
final class ItemDetails {
  const ItemDetails({
    required this.title,
    required this.accent,
    required this.provenance,
    this.glyph,
    this.subtitle,
    this.measurements = const [],
    this.properties = const [],
    this.content = const [],
  });

  /// What this is — the tool, the sender, the kind of event.
  final String title;

  /// How [title] reads, and the badge color.
  final DetailAccent accent;

  /// Who this row's content came from — the badge above the title.
  final Provenance provenance;

  /// Status badge, matching the glyph its row wears in the chat list.
  final String? glyph;

  /// A second line under the title, for a qualifier it has no room for.
  final String? subtitle;

  /// The one dim strip every item gets, in fixed slots — time, duration, size —
  /// each drawn even before its number is known.
  final List<Measurement> measurements;

  /// True while a reading on the strip is still counting.
  bool get live => measurements.any((m) => m.runningSince != null);

  /// The inputs behind the row — arguments, stats, model facts. The `{}` tab.
  final List<DetailSection> properties;

  /// What the row output.
  final List<DetailSection> content;
}
