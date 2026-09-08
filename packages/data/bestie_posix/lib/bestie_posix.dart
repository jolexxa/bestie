/// Shared POSIX implementation of Bestie's platform ports.
///
/// macOS and Linux differ in plenty of places — disk stats, system info,
/// clipboard — but terminal-environment work (redirecting fd 2, taking
/// over control keys, setting the window title) is the same libc calls on
/// both. That shared implementation lives here rather than in
/// `bestie_platform_abstractions`, so the port package stays free of any
/// native dependency and a non-POSIX platform can implement the same
/// interfaces without inheriting POSIX machinery.
library;

export 'src/bestie_posix_data_source.dart';
// `ioSinkForFd` is an implementation detail of the data source below —
// only `FdSinkException` escapes, via `TerminalOverride.originalSink`'s
// `IOSink.done`, so it needs to stay catchable.
export 'src/native_fd_sink.dart' show FdSinkException;
export 'src/posix_executable_link_data_source.dart';
