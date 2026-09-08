import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bestie_platform_windows/src/windows_terminal_data_source.dart';
import 'package:intentions/intentions.dart';
import 'package:win32_dart/win32_dart.dart';

/// Returns an [IOSink] that writes through the CRT's `_write` on [fd].
///
/// Keeps the saved original stderr reachable after descriptor 2 has been
/// pointed at a file.
IOSink ioSinkForCrtFd(CrtFd fd) => _CrtFdSink(fd);

/// Wraps a [Win32Failure] when an [IOSink] backed by a CRT descriptor
/// fails. Surfaced through [IOSink.done].
@model
@PartOf(WindowsTerminalDataSource)
final class CrtFdSinkException implements Exception {
  /// Wraps the underlying CRT [failure].
  const CrtFdSinkException(this.failure);

  /// The CRT failure that caused the sink to fail.
  final Win32Failure failure;

  @override
  String toString() => failure.toString();
}

final class _CrtFdSink implements IOSink {
  _CrtFdSink(this._fd);

  final CrtFd _fd;
  final _doneCompleter = Completer<void>();
  bool _failed = false;

  void _writeBytes(List<int> bytes) {
    if (_failed) return;
    final result = _fd.write(bytes);
    if (result is CrtWriteFailed) {
      _failed = true;
      if (!_doneCompleter.isCompleted) {
        _doneCompleter.completeError(CrtFdSinkException(result.failure));
      }
    }
  }

  void _writeString(String s) => _writeBytes(utf8.encode(s));

  @override
  void add(List<int> data) => _writeBytes(data);

  @override
  void write(Object? object) => _writeString('$object');

  @override
  void writeln([Object? object = '']) => _writeString('$object\n');

  @override
  void writeAll(Iterable<dynamic> objects, [String separator = '']) {
    var first = true;
    for (final object in objects) {
      if (!first) _writeString(separator);
      _writeString('$object');
      first = false;
    }
  }

  @override
  void writeCharCode(int charCode) =>
      _writeString(String.fromCharCode(charCode));

  @override
  Future<void> get done => _doneCompleter.future;

  @override
  Future<void> flush() => Future<void>.value();

  @override
  Future<void> close() {
    final result = _fd.close();
    if (result is CrtCloseFailed && !_doneCompleter.isCompleted) {
      _doneCompleter.completeError(CrtFdSinkException(result.failure));
    } else if (!_doneCompleter.isCompleted) {
      _doneCompleter.complete();
    }
    return _doneCompleter.future;
  }

  @override
  Future<dynamic> addStream(Stream<List<int>> stream) => stream.forEach(add);

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Encoding encoding = utf8;
}
