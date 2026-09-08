import 'dart:io';

import 'package:process_host/process_host.dart';

/// Stream factory used to listen for host `SIGWINCH` events. Injectable
/// for tests.
typedef SigwinchWatcher = Stream<void> Function();

/// Returns a stream of `SIGWINCH` events from the host process.
Stream<void> defaultSigwinchWatcher() =>
    ProcessSignal.sigwinch.watch().map((_) {});

/// Tracks the host terminal's window size, refreshing on `SIGWINCH`.
class PosixHostWinsizeSource implements HostWinsizeSource {
  /// Both [reader] and [watcher] are injectable so tests can simulate
  /// host terminal states without a real tty.
  const PosixHostWinsizeSource({
    this.reader = defaultWinsizeReader,
    this.watcher = defaultSigwinchWatcher,
  });

  /// Reads the host terminal's current dimensions.
  final WinsizeReader reader;

  /// Emits an event whenever the host terminal is resized.
  final SigwinchWatcher watcher;

  @override
  Winsize get current => currentHostWinsize(reader: reader);

  @override
  Stream<Winsize> get changes =>
      watcher().map((_) => reader()).where((w) => w != null).cast<Winsize>();
}
