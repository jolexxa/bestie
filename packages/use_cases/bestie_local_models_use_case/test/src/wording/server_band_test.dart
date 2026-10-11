import 'package:bestie_local_models_use_case/src/models/local_server_status.dart';
import 'package:bestie_local_models_use_case/src/wording/server_band.dart';
import 'package:command_protocol/command_protocol.dart';
import 'package:provider_protocol/provider_protocol.dart'
    show ProviderCancelled, ProviderOccupied, ProviderServerFailed;
import 'package:test/test.dart';

import '../../helpers/fixtures.dart';

void main() {
  final retry = PaneAction(
    key: const CharKey('r'),
    label: 'Retry',
    invoke: () async => const PaneStay(),
  );
  const loadFailed = ProviderServerFailed(
    'The local model server ran out of memory.',
  );
  const stopped = ProviderCancelled(
    'Stopped. Reconnect or pick a model to start again.',
  );

  PaneStatus bandOf(LocalServerStatus server) => serverBand(
    server,
    nameOf: (localId) => localId == 'qwen3-8b' ? 'Qwen 3 8B' : localId,
    freeBytes: 18 * gigabyte,
    retry: retry,
  );

  String textOf(PaneStatus status) => spansText(status.spans);

  test('says the server starts when a model is picked', () {
    final band = bandOf(const ServerIdle());
    expect(band.glyph, '○');
    expect(textOf(band), 'Local server starts when you pick a model');
    expect(spansText(band.trailing), '18 GB free');
    expect(band.actions, isEmpty);
  });

  test('spins while the server starts', () {
    final band = bandOf(const ServerStarting());
    expect(textOf(band), 'Starting the local server');
    expect(band.progress, isA<PaneIndeterminate>());
  });

  test('says why the app could not run on its local model', () {
    final band = bandOf(const ServerFailed(loadFailed));
    expect(band.glyph, '✕');
    expect(band.glyphTone, PaneTone.danger);
    expect(textOf(band), 'The local model server ran out of memory.');
    expect(band.trailing, isEmpty);
    expect(band.actions, [same(retry)]);
  });

  test('warns that another bestie holds the server', () {
    final band = bandOf(
      const ServerFailed(
        ProviderOccupied('Another bestie (pid 12) is using Bestie Server.'),
      ),
    );
    expect(band.glyph, '⚠');
    expect(band.glyphTone, PaneTone.warning);
    expect(band.spans.single.tone, PaneTone.warning);
    expect(textOf(band), 'Another bestie (pid 12) is using Bestie Server.');
    expect(band.actions, [same(retry)]);
  });

  test('says the model was stopped and offers to start it again', () {
    final band = bandOf(const ServerFailed(stopped));
    expect(band.glyph, '○');
    expect(band.glyphTone, isNot(PaneTone.danger));
    expect(textOf(band), stopped.message);
    expect(spansText(band.trailing), '18 GB free');
    expect(band.actions, [same(retry)]);
  });

  test('says it is measuring the context for the named model', () {
    final band = bandOf(const ServerLoading(localId: 'qwen3-8b'));
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

  test('leaves the agents out until the pool reports', () {
    expect(
      textOf(bandOf(serving(localId: 'other'))),
      'other  ready · ctx 32,768',
    );
  });
}
