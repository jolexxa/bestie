import 'package:isolate_worker/isolate_worker.dart';

final class ThrowingIsolateSpawner implements IsolateSpawner {
  const ThrowingIsolateSpawner();

  @override
  Future<SpawnedIsolate> spawn<Message>(
    void Function(Message message) entryPoint,
    Message message, {
    String? debugName,
  }) {
    throw StateError('spawn failed');
  }
}
