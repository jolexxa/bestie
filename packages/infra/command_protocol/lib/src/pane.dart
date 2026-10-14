import 'package:command_protocol/src/pane_content.dart';
import 'package:command_protocol/src/pane_filter.dart';

/// A live, navigable list a command opens inside the palette in place of a
/// parameter flow. Rows carry their own key actions, and an action can push
/// another pane on top, so panes nest under a breadcrumb.
abstract class Pane {
  const Pane();

  /// The pane's breadcrumb label.
  String get title;

  /// What the query field shows while empty; the palette's own wording for
  /// the [filter] when null.
  String? get placeholder => null;

  PaneFilter get filter => PaneFilter.fuzzy;

  /// What the footer says Esc does, which is to close the pane and go back
  /// to whatever opened it.
  String get backLabel => 'Back';

  /// The pane's sections for [query], following changes until the listener
  /// cancels. Only a [PaneFilter.search] pane is asked about anything but the
  /// empty query. Listened to again whenever the pane comes back into view.
  Stream<PaneContent> content(String query);

  /// The band under the query field; null hides it. Listened to again
  /// whenever the pane comes back into view.
  Stream<PaneStatus?> get status => const Stream.empty();
}
