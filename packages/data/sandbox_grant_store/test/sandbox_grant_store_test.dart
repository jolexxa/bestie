import 'package:file/file.dart';
import 'package:file/memory.dart';
import 'package:sandbox_grant_store/sandbox_grant_store.dart';
import 'package:test/test.dart';

void main() {
  late FileSystem fs;
  late SandboxGrantStore store;
  const path = '/home/.bestie/sandboxes.json';

  setUp(() {
    fs = MemoryFileSystem.test();
    store = SandboxGrantStore(file: path, fileSystem: fs);
  });

  final grants = SandboxGrants(
    read: const SandboxReadGrant(
      capabilitySid: 'S-1-15-3-1024-cow',
      readRoots: ['/home', '/opt/bin'],
      holes: ['/home/.ssh', '/home/.aws'],
      policyVersion: 3,
    ),
    workspaces: [
      SandboxWorkspaceEntry(
        workspaceRoot: '/home/work/repo',
        profileName: 'bestie.sandbox.abc123',
        containerSid: 'S-1-15-2-repo',
        lastSeen: DateTime.utc(2026, 8, 15),
        widenedRoots: const ['/home/.pub-cache'],
      ),
    ],
  );

  test('missing file loads as empty', () {
    final loaded = store.load();
    expect(loaded.read, isNull);
    expect(loaded.workspaces, isEmpty);
  });

  test('empty file loads as empty', () {
    fs.file(path)
      ..createSync(recursive: true)
      ..writeAsStringSync('   ');
    final loaded = store.load();
    expect(loaded.read, isNull);
    expect(loaded.workspaces, isEmpty);
  });

  test('unparseable file loads as empty', () {
    fs.file(path)
      ..createSync(recursive: true)
      ..writeAsStringSync('{ not json');
    expect(store.load().workspaces, isEmpty);
  });

  test('a document that is not the expected shape loads as empty', () {
    fs.file(path)
      ..createSync(recursive: true)
      ..writeAsStringSync('{"read": {"capabilitySid": 42}}');
    expect(store.load().read, isNull);
  });

  test('saved grants round-trip', () {
    store.save(grants);
    final loaded = store.load();

    expect(loaded.read?.capabilitySid, 'S-1-15-3-1024-cow');
    expect(loaded.read?.readRoots, ['/home', '/opt/bin']);
    expect(loaded.read?.holes, ['/home/.ssh', '/home/.aws']);
    expect(loaded.read?.policyVersion, 3);

    expect(loaded.workspaces, hasLength(1));
    final entry = loaded.workspaces.single;
    expect(entry.workspaceRoot, '/home/work/repo');
    expect(entry.profileName, 'bestie.sandbox.abc123');
    expect(entry.containerSid, 'S-1-15-2-repo');
    expect(entry.lastSeen, DateTime.utc(2026, 8, 15));
    expect(entry.widenedRoots, ['/home/.pub-cache']);
  });

  test('a document from before the write-applied flag was dropped loads', () {
    fs.file(path)
      ..createSync(recursive: true)
      ..writeAsStringSync('''
{
  "read": null,
  "workspaces": [
    {
      "workspaceRoot": "/home/work/repo",
      "profileName": "bestie.sandbox.abc123",
      "containerSid": "S-1-15-2-repo",
      "writeApplied": true,
      "lastSeen": "2026-08-15T00:00:00.000Z"
    }
  ]
}
''');

    final loaded = store.load();

    expect(loaded.workspaces.single.workspaceRoot, '/home/work/repo');
    expect(loaded.workspaces.single.lastSeen, DateTime.utc(2026, 8, 15));
    expect(loaded.workspaces.single.widenedRoots, isEmpty);
  });

  test('clear forgets the document, and a fresh load is empty', () {
    store
      ..save(grants)
      ..clear();

    expect(fs.file(path).existsSync(), isFalse);
    expect(store.load().read, isNull);
    expect(store.load().workspaces, isEmpty);
  });

  test('clear with nothing saved is a no-op', () {
    store.clear();

    expect(fs.file(path).existsSync(), isFalse);
  });

  test('save creates the parent directory', () {
    expect(fs.directory('/home/.bestie').existsSync(), isFalse);
    store.save(grants);
    expect(fs.file(path).existsSync(), isTrue);
  });

  test('save leaves no temp file behind', () {
    store.save(grants);
    expect(fs.file('$path.tmp').existsSync(), isFalse);
  });

  test('save overwrites a prior document', () {
    store
      ..save(grants)
      ..save(const SandboxGrants());
    expect(store.load().read, isNull);
    expect(store.load().workspaces, isEmpty);
  });
}
