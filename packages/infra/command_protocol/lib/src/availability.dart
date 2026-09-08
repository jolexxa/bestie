import 'dart:async';

import 'package:meta/meta.dart';

/// Builds a command's availability stream from a piece of feature state:
/// reads [current] on each listen for the seed, then follows [changes],
/// mapping every value through [gate].
Stream<Availability> gatedAvailability<T>(
  T Function() current,
  Stream<T> changes,
  Availability Function(T value) gate,
) => Stream<Availability>.multi((controller) {
  controller.add(gate(current()));
  final subscription = changes.listen((value) => controller.add(gate(value)));
  controller.onCancel = subscription.cancel;
});

/// A re-listenable availability stream that re-runs [gate] on listen and
/// again whenever any of [changes] ticks, for a precondition that draws on
/// more than one signal.
Stream<Availability> gatedAvailabilityOn(
  List<Stream<Object?>> changes,
  Availability Function() gate,
) => Stream<Availability>.multi((controller) {
  controller.add(gate());
  final subscriptions = [
    for (final stream in changes) stream.listen((_) => controller.add(gate())),
  ];
  controller.onCancel = () => Future.wait([
    for (final subscription in subscriptions) subscription.cancel(),
  ]);
});

/// A re-listenable availability stream that is always [Available] — for
/// commands with no precondition.
Stream<Availability> alwaysAvailable() => gatedAvailability<void>(
  () {},
  const Stream.empty(),
  (_) => const Available(),
);

/// Whether a command can currently run, emitted on a command's availability
/// stream so the palette can gate rows live.
@immutable
sealed class Availability {
  const Availability();
}

final class Available extends Availability {
  const Available();
}

final class Unavailable extends Availability {
  const Unavailable(this.reason);

  final String reason;
}
