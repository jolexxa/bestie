import 'dart:async';

import 'package:bestie_palette_view/src/state/palette_cubit.dart';
import 'package:command_protocol/command_protocol.dart';
import 'package:intentions/intentions.dart';

/// Owns the subscription to the current choice param's option stream.
@PartOf(PaletteCubit)
final class OptionsWatcher {
  OptionsWatcher({required this.onOptions});

  final void Function(List<Option<Object?>> options) onOptions;

  Param? _param;
  StreamSubscription<List<Option<Object?>>>? _sub;

  /// Follows [param]'s initial listing; `null` stops following anything.
  void watch(Param? param) {
    _param = param;
    _listen(switch (param) {
      ChoiceParam(:final options) => options,
      MultiChoiceParam(:final options) => options,
      _ => null,
    });
  }

  /// Re-lists for [query] when the current param searches for itself. The
  /// previous listing is dropped first, so a slow answer to an older query
  /// can never land after a newer one.
  void query(String query) {
    if (_param case ChoiceParam(filter: SearchFilter(:final search))) {
      _listen(search(query));
    }
  }

  void _listen(Stream<List<Option<Object?>>>? stream) {
    unawaited(_sub?.cancel());
    _sub = stream?.listen(onOptions);
  }
}
