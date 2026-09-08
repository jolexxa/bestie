import 'package:config_repository/config_repository.dart';
import 'package:config_repository/testing.dart';
import 'package:test/test.dart';

final _ratio = ConfigKey<double>(
  id: 'memory.compaction_ratio',
  path: const ['compaction', 'compactionRatio'],
  codec: ConfigCodecs.doubles,
  defaultValue: () => 0.85,
);

final _chars = ConfigKey<int>(
  id: 'tools.max_call_characters',
  path: const ['tools', 'maxCallCharacters'],
  codec: ConfigCodecs.integers,
  defaultValue: () => 4000,
);

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
}
