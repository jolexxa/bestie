import 'package:bestie_local_models_use_case/src/wording/server_band.dart';
import 'package:built_in_server_repository/built_in_server_repository.dart';
import 'package:command_protocol/command_protocol.dart';
import 'package:test/test.dart';

import '../../helpers/fixtures.dart';

void main() {
  final retry = PaneAction(
    key: const CharKey('r'),
    label: 'Retry',
    invoke: () async => const PaneStay(),
  );

  PaneStatus bandOf(BuiltInServerStatus server) => serverBand(
    server,
    nameOf: (localId) => localId == 'qwen3-8b' ? 'Qwen 3 8B' : localId,
    freeBytes: 18 * gigabyte,
    retry: retry,
  );

  String textOf(PaneStatus status) => spansText(status.spans);

  test('says the server is off and offers to start it', () {
    final band = bandOf(const ServerOffline());
    expect(band.glyph, '○');
    expect(textOf(band), 'Built-in server is off');
    expect(spansText(band.trailing), '18 GB free');
    expect(band.actions, [same(retry)]);
  });

  test('says why the server went off', () {
    final band = bandOf(const ServerOffline(reason: 'the server exited'));
    expect(textOf(band), 'Built-in server is off · the server exited');
    expect(band.actions, [same(retry)]);
  });

  test('spins while the server starts', () {
    final band = bandOf(const ServerStarting());
    expect(textOf(band), 'Starting the built-in server');
    expect(band.progress, isA<PaneIndeterminate>());
    expect(band.actions, isEmpty);
  });

  test('says the server waits for a model', () {
    final band = bandOf(const ServerIdle());
    expect(band.glyph, '○');
    expect(textOf(band), 'Built-in server is running · pick a model');
    expect(spansText(band.trailing), '18 GB free');
    expect(band.actions, isEmpty);
  });

  test('says it is measuring the context for the named model', () {
    final band = bandOf(const ServerFitting(localId: 'qwen3-8b'));
    expect(band.glyph, '∷');
    expect(textOf(band), 'Measuring how much context fits for Qwen 3 8B…');
  });

  test('shows loading progress for the named model', () {
    final band = bandOf(
      const ServerLoading(localId: 'qwen3-8b', progress: 0.62),
    );
    expect(band.glyph, '◑');
    expect(textOf(band), 'Loading Qwen 3 8B');
    expect((band.progress! as PaneFraction).value, 0.62);
  });

  test('shows the ready model, its context and its taken agent slots', () {
    final band = bandOf(serving(leased: 1));
    expect(band.glyph, '●');
    expect(band.glyphTone, PaneTone.success);
    expect(
      textOf(band),
      'Qwen 3 8B  ready · ctx 32,768 · 1 of 4 agent slots in use',
    );
    expect(spansText(band.trailing), '18 GB free');
  });

  test('leaves the agents out until the server reports them', () {
    expect(
      textOf(bandOf(serving(localId: 'other'))),
      'other  ready · ctx 32,768',
    );
  });

  test('says why the model could not load', () {
    final band = bandOf(
      const ServerModelFailed(localId: 'qwen3-8b', reason: 'out of memory'),
    );
    expect(band.glyph, '✕');
    expect(band.glyphTone, PaneTone.danger);
    expect(textOf(band), 'Could not load Qwen 3 8B: out of memory');
    expect(spansText(band.trailing), '18 GB free');
    expect(band.actions, [same(retry)]);
  });

  test('warns that another bestie holds the server', () {
    final band = bandOf(const ServerTaken(ownerPid: 12));
    expect(band.glyph, '⚠');
    expect(band.glyphTone, PaneTone.warning);
    expect(band.spans.single.tone, PaneTone.warning);
    expect(
      textOf(band),
      'Another bestie (pid 12) is using Bestie Server. Close it to use it '
      'here.',
    );
    expect(band.trailing, isEmpty);
    expect(band.actions, [same(retry)]);
  });

  test('warns that the running server speaks another protocol', () {
    final band = bandOf(
      const ServerIncompatible(protocolVersion: 7, serverVersion: '9.9.9'),
    );
    expect(band.glyph, '⚠');
    expect(
      textOf(band),
      'The running built-in server speaks protocol 7; this bestie speaks 1. '
      'It exits once its owner closes and it sits idle.',
    );
    expect(band.actions, [same(retry)]);
  });

  test('says why the server could not start', () {
    final band = bandOf(const ServerFailed(reason: 'no binary'));
    expect(band.glyph, '✕');
    expect(band.glyphTone, PaneTone.danger);
    expect(textOf(band), 'Could not start the built-in server: no binary');
    expect(band.trailing, isEmpty);
    expect(band.actions, [same(retry)]);
  });
}
