import 'dart:io';

import 'package:local_server/local_server.dart';
import 'package:local_server_protocol/local_server_protocol.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

import '../helpers/lock_holder.dart';

void main() {
  late Directory directory;
  late String path;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('server_lock_');
    path = p.join(directory.path, 'run', ServerLockFile.fileName);
  });

  tearDown(() => directory.deleteSync(recursive: true));

  test('takes a free lock and records where the server listens', () {
    final lock = (ServerLock.acquire(path) as ServerLockAcquired).lock
      ..publish(const ServerLockFile(pid: 9, port: 80, protocolVersion: 1))
      ..publish(const ServerLockFile(pid: 7, port: 81, protocolVersion: 1));

    expect(
      ServerLockFileMapper.fromJson(File(path).readAsStringSync()),
      const ServerLockFile(pid: 7, port: 81, protocolVersion: 1),
    );
    lock.release();
    expect(File(path).existsSync(), isTrue);
    final reacquired = ServerLock.acquire(path);
    expect(reacquired, isA<ServerLockAcquired>());
    (reacquired as ServerLockAcquired).lock.release();
  });

  test('a lock another process holds is refused with its record', () async {
    final holder = await LockHolder.hold(path);
    addTearDown(holder.release);

    expect(
      ServerLock.acquire(path),
      isA<ServerLockHeld>().having(
        (held) => held.holder,
        'holder',
        ServerLockFile(pid: holder.pid, port: 4321, protocolVersion: 1),
      ),
    );
  });

  test('a held lock without a readable record is still refused', () async {
    final holder = await LockHolder.hold(path, silent: true);
    addTearDown(holder.release);

    expect(
      ServerLock.acquire(path),
      isA<ServerLockHeld>().having((held) => held.holder, 'holder', null),
    );
  });

  test('a lock that cannot be opened fails', () {
    File(p.join(directory.path, 'run')).writeAsStringSync('in the way');

    expect(ServerLock.acquire(path), isA<ServerLockOpenFailed>());
  });
}
