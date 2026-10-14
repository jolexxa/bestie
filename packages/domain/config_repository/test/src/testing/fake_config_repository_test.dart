import 'package:config_repository/config_repository.dart';
import 'package:config_repository/testing.dart';
import 'package:test/test.dart';

final _ratio = ConfigKey<double>(
  id: 'memory.compaction_ratio',
  path: const ['compaction', 'compactionRatio'],
  codec: ConfigCodecs.doubles,
  defaultValue: () => 0.85,
  field: const NumericField(
    label: 'Compaction Ratio',
    description: 'When to compact.',
    min: 0.1,
    max: 0.95,
    step: 0.05,
  ),
);

final _chars = ConfigKey<int>(
  id: 'tools.max_call_characters',
  path: const ['tools', 'maxCallCharacters'],
  codec: ConfigCodecs.integers,
  defaultValue: () => 4000,
  field: _charsField,
);

/// Resolved along the scope's ancestry, so a model inherits the global cap.
final _scopedChars = ConfigKey<int>(
  id: 'tools.max_call_characters',
  path: const ['tools', 'maxCallCharacters'],
  codec: ConfigCodecs.integers,
  defaultValue: () => 4000,
  field: _charsField,
  resolution: const ConfigResolution.scoped(),
);

const _charsField = NumericField<int>(
  label: 'Max Tool Call Characters',
  description: 'Tool call response cap.',
  min: 500,
  max: 32000,
  step: 500,
);

final _qwen = ConfigScope.path(const ['models', 'qwen']);
final _mistral = ConfigScope.path(const ['models', 'mistral']);

void main() {
  late FakeConfigRepository config;

  setUp(() => config = FakeConfigRepository());
  tearDown(() => config.dispose());

  test('falls through to a key default when nothing was set', () {
    expect(config.resolve(_ratio.global), 0.85);
    expect(config.resolve(_chars.global), 4000);
    expect(config.isExplicit(_chars.global), isFalse);
  });

  test('resolves a value it was seeded with', () {
    final seeded = FakeConfigRepository({'tools.max_call_characters': 900});
    addTearDown(seeded.dispose);

    expect(seeded.resolve(_chars.global), 900);
    expect(seeded.isExplicit(_chars.global), isTrue);
  });

  test('announces a change when a value is set', () async {
    final seen = <Set<String>>[];
    final sub = config.changes.listen((change) => seen.add(change.keyIds));

    config['tools.max_call_characters'] = 900;
    await Future<void>.delayed(Duration.zero);

    expect(config.resolve(_chars.global), 900);
    expect(seen.single, {'tools.max_call_characters'});
    await sub.cancel();
  });

  test('announces several values as one change', () async {
    final seen = <Set<String>>[];
    final sub = config.changes.listen((change) => seen.add(change.keyIds));

    config.setAll({
      'memory.compaction_ratio': 0.5,
      'tools.max_call_characters': 900,
    });
    await Future<void>.delayed(Duration.zero);

    expect(seen.single, {
      'memory.compaction_ratio',
      'tools.max_call_characters',
    });
    await sub.cancel();
  });

  test('watch replays the current value then every distinct change', () async {
    final seen = <int>[];
    final sub = config.watch(_chars.global).listen(seen.add);
    await Future<void>.delayed(Duration.zero);

    config['tools.max_call_characters'] = 900;
    await Future<void>.delayed(Duration.zero);
    config['tools.max_call_characters'] = 900;
    await Future<void>.delayed(Duration.zero);

    expect(seen, [4000, 900]);
    // The generator is suspended awaiting the next change, so it has to be
    // let go of before the subscription can be cancelled.
    await config.dispose();
    await sub.cancel();
  });

  test('announcing without a value change notifies subscribers', () async {
    final seen = <Set<String>>[];
    final sub = config.changes.listen((change) => seen.add(change.keyIds));

    config.announce({'prompt.system'});
    await Future<void>.delayed(Duration.zero);

    expect(seen.single, {'prompt.system'});
    await sub.cancel();
  });

  test('a disposed fake stops announcing rather than throwing', () async {
    await config.dispose();

    expect(() => config.announce({'prompt.system'}), returnsNormally);
  });

  group('scopes', () {
    test('keeps a value per address', () {
      config.seed({_chars.at(_qwen): 900});

      expect(config.resolve(_chars.at(_qwen)), 900);
      expect(config.resolve(_chars.at(_mistral)), 4000);
      expect(config.resolve(_chars.global), 4000);
      expect(config.isExplicit(_chars.at(_qwen)), isTrue);
      expect(config.isExplicit(_chars.at(_mistral)), isFalse);
      expect(config['tools.max_call_characters'], isNull);
    });

    test('a scoped key inherits from its ancestors', () {
      config['tools.max_call_characters'] = 900;

      final inherited = config.inspect(_scopedChars.at(_qwen));
      expect(inherited.value, 900);
      expect(inherited.source, _scopedChars.global);
      expect(config.resolve(_chars.at(_qwen)), 4000);
    });

    test('announces seeded addresses as one change', () async {
      final seen = <ConfigChange>[];
      final sub = config.changes.listen(seen.add);

      config.seed({_chars.at(_qwen): 900, _ratio.global: 0.5});
      await Future<void>.delayed(Duration.zero);

      expect(seen.single.contains(_chars.at(_qwen)), isTrue);
      expect(seen.single.contains(_chars.at(_mistral)), isFalse);
      expect(seen.single.keyIds, {
        'tools.max_call_characters',
        'memory.compaction_ratio',
      });
      await sub.cancel();
    });

    test('sets one value at an address and announces it', () async {
      final seen = <ConfigChange>[];
      final sub = config.changes.listen(seen.add);

      config.set(_chars.at(_qwen), 900);
      await Future<void>.delayed(Duration.zero);

      expect(config.resolve(_chars.at(_qwen)), 900);
      expect(seen.single.contains(_chars.at(_qwen)), isTrue);
      await sub.cancel();
    });

    test('scope defaults stand in per address until a value is set', () async {
      final seen = <ConfigChange>[];
      final sub = config.changes.listen(seen.add);

      config.applyScopeDefaults({_chars.at(_qwen): 1500});
      await Future<void>.delayed(Duration.zero);

      expect(config.resolve(_chars.at(_qwen)), 1500);
      expect(config.resolve(_chars.at(_mistral)), 4000);
      expect(config.defines(_chars.at(_qwen)), isTrue);
      expect(config.isExplicit(_chars.at(_qwen)), isFalse);
      expect(config.defines(_chars.at(_mistral)), isFalse);
      expect(seen.single.contains(_chars.at(_qwen)), isTrue);

      config.set(_chars.at(_qwen), 900);
      expect(config.resolve(_chars.at(_qwen)), 900);
      await sub.cancel();
    });

    test('commits and clears edits at their addresses', () async {
      final seen = <ConfigChange>[];
      final sub = config.changes.listen(seen.add);

      config.commit({_chars.at(_qwen): const ConfigEdit<int>.set(900)});
      expect(config.resolve(_chars.at(_qwen)), 900);

      config.applyLive({_chars.at(_qwen): const ConfigEdit<int>.clear()});
      expect(config.resolve(_chars.at(_qwen)), 4000);

      config.commit(const {});
      await Future<void>.delayed(Duration.zero);

      expect(seen, hasLength(2));
      expect(seen.first.contains(_chars.at(_qwen)), isTrue);
      await sub.cancel();
    });

    test('reads through its own view', () {
      config.set(_chars.at(_qwen), 900);

      expect(config.view().resolve(_chars.at(_qwen)), 900);
      expect(config.view().resolveBase(_chars.at(_qwen)), 900);
    });
  });
}
