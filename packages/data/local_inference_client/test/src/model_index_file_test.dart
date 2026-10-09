import 'dart:async';
import 'dart:io'
    show
        FileSystemCreateEvent,
        FileSystemEvent,
        FileSystemException,
        FileSystemModifyEvent,
        FileSystemMoveEvent;

import 'package:file/file.dart';
import 'package:local_inference_client/src/model_index_file.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockFileSystem extends Mock implements FileSystem {}

class MockFile extends Mock implements File {}

class MockDirectory extends Mock implements Directory {}

void main() {
  const indexPath = '/bestie/models/index.json';

  late MockFileSystem fileSystem;
  late MockDirectory folder;
  late StreamController<FileSystemEvent> events;
  late ModelIndexFile index;

  setUp(() {
    fileSystem = MockFileSystem();
    final file = MockFile();
    folder = MockDirectory();
    events = StreamController<FileSystemEvent>();
    when(() => fileSystem.file(indexPath)).thenReturn(file);
    when(() => file.parent).thenReturn(folder);
    when(() => folder.createSync(recursive: true)).thenReturn(null);
    when(folder.watch).thenAnswer((_) => events.stream);
    index = ModelIndexFile(fileSystem: fileSystem, path: indexPath);
  });

  Future<int> changesAfter(void Function() happen) async {
    var changes = 0;
    final watching = index.changes.listen((_) => changes++);
    happen();
    await pumpEventQueue();
    await watching.cancel();
    return changes;
  }

  group('changes', () {
    test('follow the index being written', () async {
      expect(
        await changesAfter(
          () => events
            ..add(FileSystemModifyEvent(indexPath, false, true))
            ..add(FileSystemCreateEvent(indexPath, false)),
        ),
        2,
      );
    });

    test('follow a file renamed into the index', () async {
      expect(
        await changesAfter(
          () => events.add(
            FileSystemMoveEvent(
              '/bestie/models/index.json.tmp',
              false,
              indexPath,
            ),
          ),
        ),
        1,
      );
    });

    test('ignore other files in the folder', () async {
      expect(
        await changesAfter(
          () => events
            ..add(FileSystemCreateEvent('/bestie/models/qwen.gguf', false))
            ..add(
              FileSystemMoveEvent('/bestie/models/a.part', false, null),
            ),
        ),
        0,
      );
    });

    test('carry on past a watch error', () async {
      expect(
        await changesAfter(
          () => events
            ..addError(const FileSystemException('overflow'))
            ..add(FileSystemCreateEvent(indexPath, false)),
        ),
        1,
      );
    });

    test('end when the watch ends', () async {
      final ended = Completer<void>();
      index.changes.listen((_) {}, onDone: ended.complete);

      await events.close();

      await expectLater(ended.future, completes);
    });

    test('stop watching once nobody listens', () async {
      await changesAfter(() {});

      expect(events.hasListener, isFalse);
    });

    test('never come when the folder cannot be made', () async {
      when(
        () => folder.createSync(recursive: true),
      ).thenThrow(const FileSystemException('read-only'));
      final ended = Completer<void>();

      index.changes.listen((_) {}, onDone: ended.complete);

      await expectLater(ended.future, completes);
      verifyNever(folder.watch);
    });
  });
}
