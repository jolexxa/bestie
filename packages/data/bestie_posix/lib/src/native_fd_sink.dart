import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bestie_posix/src/bestie_posix_data_source.dart';
import 'package:intentions/intentions.dart';
import 'package:posix_dart/posix_dart.dart';

/// Returns an [IOSink] that writes to raw file descriptor [fd] via
/// libc's `write(2)`. Used to keep writing to a saved fd after the
/// original has been redirected (e.g., the saved stderr fd after fd
/// 2 was pointed at `/dev/null`).
IOSink ioSinkForFd({required int fd, PosixFd? fdApi}) =>
    _FdBackedSink(fd, fdApi ?? posixFd);

/// Wraps a [PosixFailure] when an [IOSink] backed by a raw fd
/// fails. Surfaced through [IOSink.done].
@model
@PartOf(BestiePosixDataSource)
final class FdSinkException implements Exception {
  /// Wraps the underlying libc [failure].
  const FdSinkException(this.failure);

  /// The libc failure that caused the sink to fail.
  final PosixFailure failure;

  @override
  String toString() => failure.toString();
}

final class _FdBackedSink implements IOSink {
  _FdBackedSink(this._fd, this._api);

  final int _fd;
  final PosixFd _api;
  final _doneCompleter = Completer<void>();
  bool _failed = false;

  void _writeBytes(List<int> bytes) {
    if (_failed) return;
    final result = _api.write(_fd, bytes);
    if (result is FdWriteFailed) {
      _failed = true;
      if (!_doneCompleter.isCompleted) {
        _doneCompleter.completeError(FdSinkException(result.failure));
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
    for (final obj in objects) {
      if (!first) _writeString(separator);
      _writeString('$obj');
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
    final result = _api.close(_fd);
    if (result is FdCloseFailed && !_doneCompleter.isCompleted) {
      _doneCompleter.completeError(FdSinkException(result.failure));
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
