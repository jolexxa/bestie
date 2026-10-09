import 'dart:io';

import 'package:inference_server/inference_server.dart';
import 'package:local_inference_protocol/local_inference_protocol.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../helpers/lock_holder.dart';

void main() {
  late Directory directory;
  late String path;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('inference_lock_');
    path = p.join(directory.path, 'run', InferenceLockFile.fileName);
  });

  tearDown(() => directory.deleteSync(recursive: true));

  test('takes a free lock and records where the server listens', () {
    final lock = (InferenceLock.acquire(path) as InferenceLockAcquired).lock
      ..publish(const InferenceLockFile(pid: 9, port: 80, protocolVersion: 1))
      ..publish(const InferenceLockFile(pid: 7, port: 81, protocolVersion: 1));

    expect(
      InferenceLockFileMapper.fromJson(File(path).readAsStringSync()),
      const InferenceLockFile(pid: 7, port: 81, protocolVersion: 1),
    );
    lock.release();
    expect(File(path).existsSync(), isTrue);
    expect(InferenceLock.acquire(path), isA<InferenceLockAcquired>());
  });

  test('a lock another process holds is refused with its record', () async {
    final holder = await LockHolder.hold(path);
    addTearDown(holder.release);

    expect(
      InferenceLock.acquire(path),
      isA<InferenceLockHeld>().having(
        (held) => held.holder,
        'holder',
        InferenceLockFile(pid: holder.pid, port: 4321, protocolVersion: 1),
      ),
    );
  });

  test('a held lock without a readable record is still refused', () async {
    final holder = await LockHolder.hold(path, silent: true);
    addTearDown(holder.release);

    expect(
      InferenceLock.acquire(path),
      isA<InferenceLockHeld>().having((held) => held.holder, 'holder', null),
    );
  });

  test('a lock that cannot be opened fails', () {
    File(p.join(directory.path, 'run')).writeAsStringSync('in the way');

    expect(InferenceLock.acquire(path), isA<InferenceLockFailed>());
  });
}
