import 'dart:async';

import 'package:bestie_palette_view/src/models/pane_frame.dart';
import 'package:bestie_palette_view/src/state/palette_cubit.dart';
import 'package:command_protocol/command_protocol.dart';
import 'package:intentions/intentions.dart';

/// Owns the subscriptions to the visible pane's content and status streams.
@PartOf(PaletteCubit)
final class PaneWatcher {
  PaneWatcher({
    required this.onContent,
    required this.onStatus,
    required this.onFailed,
  });

  final void Function(PaneContent content) onContent;
  final void Function(PaneStatus? status) onStatus;
  final void Function(PaneFrame frame, Object error) onFailed;

  StreamSubscription<PaneContent>? _content;
  StreamSubscription<PaneStatus?>? _status;

  /// Follows [frame]'s pane for its current query; `null` stops following
  /// anything.
  void watch(PaneFrame? frame) {
    unawaited(_content?.cancel());
    unawaited(_status?.cancel());
    _content = null;
    _status = null;
    if (frame == null) return;
    _content = _listenContent(frame);
    _status = frame.pane.status.listen(
      onStatus,
      onError: (Object error) => onFailed(frame, error),
    );
  }

  /// Re-lists [frame] for its query when its pane searches for itself. The
  /// previous listing is dropped first, so a slow answer to an older query
  /// can never land after a newer one.
  void query(PaneFrame frame) {
    if (frame.pane.filter != PaneFilter.search) return;
    unawaited(_content?.cancel());
    _content = _listenContent(frame);
  }

  StreamSubscription<PaneContent> _listenContent(PaneFrame frame) => frame.pane
      .content(switch (frame.pane.filter) {
        PaneFilter.search => frame.query,
        PaneFilter.fuzzy || PaneFilter.none => '',
      })
      .listen(onContent, onError: (Object error) => onFailed(frame, error));
}
