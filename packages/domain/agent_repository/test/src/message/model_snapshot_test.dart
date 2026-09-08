import 'package:agent_repository/agent_repository.dart';
import 'package:test/test.dart';

void main() {
  const ready = ModelSnapshot.remote(
    modelId: 'openai/gpt-4o-mini',
    displayName: 'GPT-4o mini',
    contextSize: 128000,
    provider: 'OpenRouter',
  );

  test('a remote snapshot is ready with no progress or error', () {
    expect(ready.phase, ModelCardPhase.ready);
    expect(ready.progress, isNull);
    expect(ready.error, isNull);
  });

  test('compares by value', () {
    const same = ModelSnapshot(
      modelId: 'openai/gpt-4o-mini',
      displayName: 'GPT-4o mini',
      contextSize: 128000,
      provider: 'OpenRouter',
      phase: ModelCardPhase.ready,
    );
    const failed = ModelSnapshot(
      modelId: 'openai/gpt-4o-mini',
      displayName: 'GPT-4o mini',
      contextSize: 128000,
      provider: 'OpenRouter',
      phase: ModelCardPhase.failed,
      error: 'boom',
    );

    expect(ready, same);
    expect(ready.hashCode, same.hashCode);
    expect(ready, isNot(failed));
    expect(failed.toString(), contains('boom'));
  });

  test('a legacy model change decodes with the local provider', () {
    final entry = ModelChangeEntryMapper.fromMap({
      'id': 'm1',
      'timestamp': '2025-01-01T00:00:00.000Z',
      'modelId': 'org/model',
      'displayName': 'Model',
      'backend': 'llama_cpp',
      'quantLabel': 'Q4_K_M',
      'contextSize': 4096,
      'totalBytes': 1000,
    });

    expect(entry.provider, ModelChangeEntry.legacyModelProvider);
    expect(entry.contextSize, 4096);
  });
}
