import 'package:bestie_local_models_use_case/src/wording/server_band.dart';
import 'package:command_protocol/command_protocol.dart';
import 'package:inference_protocol/inference_protocol.dart'
    show InferenceFailureKind;
import 'package:local_server_repository/local_server_repository.dart';
import 'package:provider_protocol/provider_protocol.dart' show ProviderFailure;
import 'package:test/test.dart';

import '../../helpers/fixtures.dart';

void main() {
  final retry = PaneAction(
    key: const CharKey('r'),
    label: 'Retry',
    invoke: () async => const PaneStay(),
  );
  const loadFailed = ProviderFailure(
    kind: InferenceFailureKind.server,
    message: 'The local model server ran out of memory.',
  );
  const stopped = ProviderFailure(
    kind: InferenceFailureKind.cancelled,
    message: 'Stopped. Reconnect or pick a model to start again.',
  );

  PaneStatus bandOf(LocalServerStatus server, {ProviderFailure? failure}) =>
      serverBand(
        server,
        failure: failure,
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

  test('gives the reason the server went away', () {
    final band = bandOf(const ServerFailed('The server exited'));
    expect(textOf(band), 'The server exited');
    expect(spansText(band.trailing), '18 GB free');
    expect(band.actions, isEmpty);
  });

  test('spins while the server starts', () {
    final band = bandOf(const ServerStarting());
    expect(textOf(band), 'Starting the local server');
    expect(band.progress, isA<PaneIndeterminate>());
  });

  group('when another window owns the server', () {
    const owned = ServerOwnedElsewhere(ownerPid: 4121);

    test('warns', () {
      final band = bandOf(owned);
      expect(band.glyph, '⚠');
      expect(
        textOf(band),
        'Another bestie (pid 4121) is using Bestie Server. Close it '
        'to use it here.',
      );
      expect(band.trailing, isEmpty);
      expect(band.actions, isEmpty);
    });

    test('offers to try again once the app could not run on it', () {
      final band = bandOf(owned, failure: loadFailed);
      expect(textOf(band), contains('pid 4121'));
      expect(band.actions, [same(retry)]);
    });
  });

  group('when the running server speaks another protocol', () {
    const incompatible = ServerIncompatible(
      serverVersion: '0.3.0',
      protocolVersion: 2,
    );

    test('warns', () {
      final band = bandOf(incompatible);
      expect(band.glyph, '⚠');
      expect(
        textOf(band),
        'The running local server (0.3.0) speaks protocol 2; it exits once '
        'its owner closes.',
      );
      expect(band.actions, isEmpty);
    });

    test('offers to try again once the app could not run on it', () {
      expect(bandOf(incompatible, failure: loadFailed).actions, [
        same(retry),
      ]);
    });
  });

  test('says why the app could not run on its local model', () {
    final band = bandOf(const ServerIdle(), failure: loadFailed);
    expect(band.glyph, '✕');
    expect(band.glyphTone, PaneTone.danger);
    expect(textOf(band), 'The local model server ran out of memory.');
    expect(band.trailing, isEmpty);
    expect(band.actions, [same(retry)]);
  });

  test('says the model was stopped and offers to start it again', () {
    final band = bandOf(const ServerIdle(), failure: stopped);
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
    final band = bandOf(
      serving(pool: const LocalAgentPool(leased: 1, maxAgents: 4)),
    );
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

  test('says the model failed to load and why', () {
    final band = bandOf(
      const ServerLoadFailed(
        localId: 'qwen3-8b',
        reason: 'not enough memory for 4k context.',
      ),
    );
    expect(band.glyph, '✕');
    expect(
      textOf(band),
      "The local server couldn't load Qwen 3 8B: not enough memory for 4k "
      'context.',
    );
    expect(band.trailing, isEmpty);
    expect(band.actions, isEmpty);
  });
}
