import 'dart:convert';
import 'dart:typed_data';

import 'package:file/file.dart';
import 'package:files_data_source/src/bounded_head.dart';
import 'package:files_data_source/src/line_window_scan.dart';
import 'package:files_data_source/src/models/directory_entry.dart';
import 'package:files_data_source/src/models/file_facts.dart';
import 'package:files_data_source/src/models/file_kind.dart';
import 'package:files_data_source/src/models/stored_body.dart';
import 'package:files_data_source/src/models/text_extent.dart';
import 'package:files_data_source/src/record_file.dart';
import 'package:files_data_source/src/utf8_window.dart';
import 'package:intentions/intentions.dart';
import 'package:path/path.dart' as p;
import 'package:tool_protocol/tool_protocol.dart';

/// Bytes sampled when deciding whether a file holds text.
const _binarySampleSize = 512;

/// Characters of a stored tool output's beginning the store keeps in hand to
/// answer with, sparing a read back off disk.
const int defaultToolCacheChars = 1 << 15;

/// Reads, writes, and pages files.
@dataSource
final class FilesDataSource {
  FilesDataSource({
    required FileSystem fileSystem,
    String workingDirectory = '.',
    this.headCacheChars = defaultToolCacheChars,
  }) : _fileSystem = fileSystem,
       _workingDirectory = workingDirectory;

  final FileSystem _fileSystem;
  final String _workingDirectory;

  /// Characters of head [storeLines] and [storeProse] keep in hand — a
  /// retention policy of this store, not anyone's reply budget.
  final int headCacheChars;

  p.Context get _path => _fileSystem.path;

  /// [path] spelled the way this filesystem spells it, whether or not
  /// anything is there.
  String pathOf(String path) => _absolute(_resolve(path));

  /// What sits at [path], or null when nothing does. A symlink is named as
  /// one, but its size, times, and mode are the target's.
  Future<FileFacts?> factsOf(String path) async {
    final resolved = _resolve(path);
    final stat = await _fileSystem.stat(resolved);
    if (stat.type == FileSystemEntityType.notFound) return null;
    return FileFacts(
      path: _absolute(resolved),
      kind: _kindOfType(
        await _fileSystem.type(resolved, followLinks: false),
      ),
      size: stat.size,
      modified: stat.modified,
      accessed: stat.accessed,
      changed: stat.changed,
      mode: stat.mode,
      modeDescription: stat.modeString(),
    );
  }

  /// Whether [path] holds something other than text, judged by its first
  /// bytes. Anything that cannot be opened counts as not text.
  Future<bool> looksBinary(String path) async {
    final handle = await _open(path);
    if (handle == null) return true;
    try {
      final sample = Uint8List(_binarySampleSize);
      final read = await handle.readInto(sample);
      return sample.sublist(0, read).contains(0);
    } on FileSystemException {
      return true;
    } finally {
      await handle.close();
    }
  }

  /// How much text [path] holds, by both measures.
  Future<TextExtent> extentOf(String path) async {
    final page = await readLines(path, limit: 0);
    final file = _fileSystem.file(_resolve(path));
    return TextExtent(lines: page.extent.tally, bytes: await file.length());
  }

  /// Text of [path] from [at], spanning at most [limit] lines and holding at
  /// most [chars] characters, endings normalized and every line carrying its
  /// newline.
  Future<Excerpt<LinePlace>> readLines(
    String path, {
    LinePlace at = LinePlace.start,
    int? limit,
    int? chars,
  }) async {
    final scan = LineWindowScan(at: at, limit: limit, chars: chars);
    await _fileSystem
        .file(_resolve(path))
        .openRead()
        .transform(const Utf8Decoder(allowMalformed: true))
        .forEach(scan.add);
    return scan.finish();
  }

  /// A byte window of [path] beginning at [offset], reading at most [length]
  /// bytes and decoded on whole UTF-8 character boundaries.
  Future<Excerpt<BytePlace>> readBytes(
    String path, {
    required int length,
    int offset = 0,
  }) async {
    final file = _fileSystem.file(_resolve(path));
    final total = await file.length();
    final from = offset.clamp(0, total);

    if (length <= 0 || from >= total) {
      return Excerpt.bytes('', start: from, total: total);
    }

    final handle = await file.open();
    final Uint8List chunk;
    try {
      await handle.setPosition(from);
      chunk = await handle.read(length);
    } finally {
      await handle.close();
    }

    final window = utf8Window(chunk);
    // An empty window with bytes remaining is a fragment no fuller read can
    // complete; shown as replacements, a reader moves past it.
    final end = window.isEmpty && window.start < chunk.length
        ? chunk.length
        : window.end;
    return Excerpt.bytes(
      utf8.decode(chunk.sublist(window.start, end), allowMalformed: true),
      start: from + window.start,
      total: total,
    );
  }

  /// Writes every line of [lines] to [path], creating parents, and answers
  /// with as much of the beginning as [headCacheChars] kept.
  Future<StoredBody> storeLines(String path, Stream<String> lines) async {
    final file = await _prepare(path);
    final sink = file.openWrite();
    final head = BoundedHead(maxChars: headCacheChars);
    var totalChars = 0;
    var totalLines = 0;
    var lastLine = 0;

    try {
      await for (final line in lines) {
        final first = totalLines == 0;
        if (!first) sink.write('\n');
        sink.write(line);
        head.add(line, first: first);
        totalChars += first ? line.length : line.length + 1;
        totalLines += 1;
        lastLine = line.length;
      }
      await sink.flush();
    } finally {
      await sink.close();
    }

    return StoredBody(
      head: Excerpt.lines(
        head.text,
        extent: totalLines == 0
            ? LinePlace.start
            : LinePlace(line: totalLines - 1, into: lastLine),
      ),
      totalChars: totalChars,
      storedAt: file.absolute.path,
    );
  }

  /// Opens [path] for recording, creating parents, for output written once and
  /// then read out of order. The caller closes it with `finish`.
  Future<RecordFile> openRecordFile(String path) async =>
      RecordFile.create(await _prepare(path));

  /// Opens the recording at [path] to read, or null when nothing is there —
  /// anything that is not a recording opening as one holding no records.
  Future<RecordFile?> openRecords(String path) async {
    final resolved = _resolve(path);
    final stat = await _fileSystem.stat(resolved);
    if (stat.type != FileSystemEntityType.file) return null;
    return RecordFile.open(_fileSystem.file(resolved));
  }

  /// [text] with every line ending spelled as a bare newline.
  static String _normalized(String text) =>
      text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

  /// Writes [text] to [path], creating parents, and answers with as much of
  /// the beginning as [headCacheChars] kept.
  Future<StoredBody> storeProse(String path, String text) async {
    final file = await _prepare(path);
    final body = _normalized(text);
    await file.writeAsString(body, flush: true);
    return StoredBody(
      head: Excerpt.lines(
        Excerpt.clip(body, headCacheChars),
        extent: LinePlace.start.advanced(body),
      ),
      totalChars: body.length,
      storedAt: file.absolute.path,
    );
  }

  /// Lines of [path] one at a time, for callers that examine text rather than
  /// answer with it. A file that cannot be read yields nothing, so one bad
  /// file does not end a sweep across many.
  Stream<String> readableLines(String path) => _fileSystem
      .file(_resolve(path))
      .openRead()
      .transform(const Utf8Decoder(allowMalformed: true))
      .transform(const LineSplitter())
      .handleError((_) {}, test: (error) => error is FileSystemException);

  /// Children of the directory at [path]. Descending is the caller's to do,
  /// so it can decline before a directory is ever opened.
  Stream<DirectoryEntry> children(String path) async* {
    final directory = _fileSystem.directory(_resolve(path));
    final Stream<FileSystemEntity> listing;
    try {
      listing = directory
          .list(followLinks: false)
          .handleError(
            (_) {},
            test: (error) => error is FileSystemException,
          );
    } on FileSystemException {
      return;
    }

    await for (final entity in listing) {
      final kind = switch (entity) {
        Directory() => FileKind.directory,
        File() => FileKind.file,
        Link() => FileKind.link,
        _ => FileKind.unknown,
      };
      yield DirectoryEntry(
        name: _path.basename(entity.path),
        path: entity.absolute.path,
        kind: kind,
        size: entity is File ? await _lengthOf(entity) : 0,
      );
    }
  }

  Future<int> _lengthOf(File file) async {
    try {
      return await file.length();
    } on FileSystemException {
      return 0;
    }
  }

  Future<RandomAccessFile?> _open(String path) async {
    try {
      return await _fileSystem.file(_resolve(path)).open();
    } on FileSystemException {
      return null;
    }
  }

  Future<File> _prepare(String path) async {
    final file = _fileSystem.file(_resolve(path));
    await file.parent.create(recursive: true);
    return file;
  }

  String _resolve(String rawPath) => _path.isAbsolute(rawPath)
      ? rawPath
      : _path.normalize(_path.join(_workingDirectory, rawPath));

  String _absolute(String resolved) => _fileSystem.file(resolved).absolute.path;

  FileKind _kindOfType(FileSystemEntityType type) => switch (type) {
    FileSystemEntityType.file => FileKind.file,
    FileSystemEntityType.directory => FileKind.directory,
    FileSystemEntityType.link => FileKind.link,
    _ => FileKind.unknown,
  };
}
