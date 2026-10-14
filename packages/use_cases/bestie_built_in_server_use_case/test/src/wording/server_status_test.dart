import 'package:bestie_built_in_server_use_case/src/wording/server_status.dart';
import 'package:built_in_server_repository/built_in_server_repository.dart';
import 'package:command_protocol/command_protocol.dart';
import 'package:test/test.dart';

void main() {
  String? textOf(BuiltInServerStatus server) =>
      serverStatus(server)?.spans.map((span) => span.text).join();

  PaneTone toneOf(BuiltInServerStatus server) =>
      serverStatus(server)!.spans.single.tone;

  test('says nothing while the server is off', () {
    expect(serverStatus(const ServerOffline()), isNull);
    expect(serverStatus(const ServerOffline(reason: 'gone')), isNull);
  });

  test('follows the server getting a model ready', () {
    expect(textOf(const ServerStarting()), '◑ starting');
    expect(toneOf(const ServerStarting()), PaneTone.loading);
    expect(textOf(const ServerIdle()), '● running');
    expect(toneOf(const ServerIdle()), PaneTone.success);
    expect(textOf(const ServerFitting(localId: 'qwen')), '◑ fitting qwen');
    expect(
      textOf(const ServerLoading(localId: 'qwen', progress: .424)),
      '◑ loading qwen 42%',
    );
    expect(
      toneOf(const ServerLoading(localId: 'qwen', progress: .424)),
      PaneTone.loading,
    );
    expect(
      serverStatus(
        const ServerLoading(localId: 'qwen', progress: .424),
      )!.progress,
      isNull,
    );
  });

  test('names the model it serves', () {
    const serving = ServerServing(
      localId: 'qwen',
      contextSize: 32768,
      maxAgents: 4,
      deviceBytes: 6100000000,
    );
    expect(textOf(serving), '● qwen ready');
    expect(toneOf(serving), PaneTone.success);
  });

  test('says what went wrong', () {
    const modelFailed = ServerModelFailed(localId: 'qwen', reason: 'oom');
    expect(textOf(modelFailed), '✕ qwen failed');
    expect(toneOf(modelFailed), PaneTone.danger);

    const taken = ServerTaken(ownerPid: 12);
    expect(textOf(taken), '⚠ in use elsewhere');
    expect(toneOf(taken), PaneTone.warning);

    const incompatible = ServerIncompatible(
      protocolVersion: 2,
      serverVersion: '1.0',
    );
    expect(textOf(incompatible), '⚠ incompatible');
    expect(toneOf(incompatible), PaneTone.warning);

    const failed = ServerFailed(reason: 'no binary');
    expect(textOf(failed), '✕ failed');
    expect(toneOf(failed), PaneTone.danger);
  });
}
