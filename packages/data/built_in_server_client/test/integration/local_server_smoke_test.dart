// A smoke test reports what it saw.
// ignore_for_file: avoid_print
@Tags(['integration'])
library;

import 'dart:async';
import 'dart:ffi' show Abi;
import 'dart:io';

import 'package:agent_runtime_protocol/agent_runtime_protocol.dart';
import 'package:bestie_platform_abstractions/bestie_platform_abstractions.dart';
import 'package:built_in_server_client/built_in_server_client.dart';
import 'package:file/local.dart';
import 'package:http/http.dart' as http;
import 'package:local_server_protocol/local_server_protocol.dart';
import 'package:path/path.dart' as p;
import 'package:process_host_posix/process_host_posix.dart';
import 'package:provider_protocol/provider_protocol.dart';
import 'package:test/test.dart';

/// Starts the real server from source against a scratch bestie directory
/// whose index names one GGUF, then drives it the way bestie does.
/// Run with `dart test --run-skipped -t integration`; `BESTIE_SMOKE_GGUF`
/// overrides the model.
void main() {
  final home = Platform.environment['HOME'] ?? '';
  final gguf = File(
    Platform.environment['BESTIE_SMOKE_GGUF'] ??
        '$home/Dropbox/AI/models/Qwen3-1.7B-Q4_K_M.gguf',
  );
  const localId = 'qwen3-1.7b-q4_k_m-f157866c';
  final repoRoot = p.normalize(
    p.join(Directory.current.path, '..', '..', '..'),
  );

  test(
    'spawns, attaches, loads, runs agents, and refuses a second owner',
    skip: 'Starts the real server and loads a model; run with --run-skipped.',
    timeout: const Timeout(Duration(minutes: 5)),
    () async {
      final bestieDir = Directory.systemTemp.createTempSync('bestie_smoke');
      addTearDown(() => bestieDir.deleteSync(recursive: true));
      _writeIndex(bestieDir.path, gguf, localId);
      print('bestie dir: ${bestieDir.path}');

      BuiltInServerClient connectionFor(int pid) => BuiltInServerClient(
        client: http.Client(),
        sessionClientFactory: http.Client.new,
        fileSystem: const LocalFileSystem(),
        lockFile: serverLockFileFor(bestieDir.path, p.context),
        indexFile: p.join(
          modelsDirFor(bestieDir.path, p.context),
          ModelIndex.fileName,
        ),
        launch: BuiltInServerLaunch(
          command: ProgramCommand(
            executable: Platform.resolvedExecutable,
            arguments: [
              'run',
              p.join(repoRoot, 'packages/bestie_server/bin/bestie_server.dart'),
            ],
          ),
          bestieDir: bestieDir.path,
          logFile: serverLogFileFor(bestieDir.path, p.context),
        ),
        pid: pid,
        spawner: SupervisedServerSpawner(
          host: PosixProcessHost(
            spawnerBinaryPath: p.join(
              repoRoot,
              'packages/ffi/posix_spawner/assets/native',
              Platform.operatingSystem,
              Abi.current() == Abi.macosArm64 || Abi.current() == Abi.linuxArm64
                  ? 'arm64'
                  : 'x64',
              'spawner',
            ),
          ),
          environment: Platform.environment,
        ),
      );

      final first = connectionFor(pid);
      final listed = await first.models();
      final models = (listed as ProviderModelsListed).models;
      for (final entry in models) {
        print(
          'model ${entry.id}: ${entry.name}, ${entry.contextLength} ctx, '
          'reasoning ${entry.reasoning}',
        );
      }
      expect(models.single.id, localId);
      final request = ProviderModelLoadRequest(
        modelId: localId,
        contextWindow: models.single.contextLength!,
        maxAgents: 3,
      );

      final load = first.load(request);
      final steps = <String>[];
      load.progress.listen((progress) => steps.add('$progress'));
      final loaded = await load.result;
      print('load progress: ${steps.join(' ')}');
      final model = (loaded as ProviderModelLoaded).model;
      print(
        'loaded: ${model.contextWindow} ctx, ${model.maxAgents} agents, '
        '${model.deviceBytes} bytes',
      );

      final agents = model.runtime;
      final snapshots = <ContextPoolSnapshot>[];
      agents.pool.listen(snapshots.add);

      final primary =
          (await agents.startPrimary(config: _config) as StartPrimaryStarted)
              .agent;
      final subagent =
          (await agents.startSubagent(config: _config, label: 'helper')
                  as StartSubagentStarted)
              .agent;
      print(
        'pool: ${snapshots.last.contextSize} ctx, '
        '${snapshots.last.reservedClaims} reserved, ${snapshots.last.leases}',
      );

      final turns = await Future.wait([
        _runTurn(primary, 'Name one primary color. One word.'),
        _runTurn(subagent, 'Name one planet. One word.'),
      ]);
      print('primary said: ${turns[0]}');
      print('subagent said: ${turns[1]}');
      expect(turns, everyElement(isNotEmpty));

      final second = connectionFor(pid + 1);
      final busy = await second.load(request).result;
      final refusal = (busy as ProviderModelLoadFailed).failure.message;
      print('second bestie: $refusal');
      expect(refusal, bestieServerBusyMessage(pid));

      await agents.dispose();
      await first.close();
      final third = connectionFor(pid + 2);
      var freed = await third.load(request).result;
      print('after the first closed: $freed');
      expect(freed, isA<ProviderModelLoaded>());

      final lockFile = File(serverLockFileFor(bestieDir.path, p.context));
      int serverPid() =>
          ServerLockFileMapper.fromJson(lockFile.readAsStringSync()).pid;
      final pids = [serverPid()];
      for (var round = 0; round < 3; round++) {
        await (freed as ProviderModelLoaded).model.release();
        freed = await third.load(request).result;
        print('re-picked after a release: $freed (pid ${serverPid()})');
        expect(freed, isA<ProviderModelLoaded>());
        pids.add(serverPid());
      }
      expect(pids.toSet(), hasLength(pids.length));

      await third.close();
      await second.close();
      final exited = Stopwatch()..start();
      while (Process.killPid(serverPid(), ProcessSignal.sigcont)) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      print('the last server exited ${exited.elapsedMilliseconds} ms after');
      final lifecycle = RegExp('Listening|Waiting|Shutting|exit code');
      File(serverLogFileFor(bestieDir.path, p.context))
          .readAsLinesSync()
          .where(lifecycle.hasMatch)
          .forEach((line) => print('  server: $line'));
    },
  );
}

const _config = AgentConfig(
  systemPrompt: 'Answer in one word.',
  sampling: SamplingOptions(seed: 7, temperature: 0.2),
  reasoningMode: 'off',
  compactionReasoningMode: 'off',
  compactionRatio: 0.8,
  tools: [],
);

Future<String> _runTurn(Agent agent, String prompt) async {
  final text = StringBuffer();
  final done = Completer<void>();
  final events = agent.events.listen((event) {
    switch (event) {
      case AgentTextDelta(:final text) when text.isNotEmpty:
        print('  ${agent.handle.id} ▸ $text');
      default:
        break;
    }
    if (event case AgentTextDelta(text: final delta)) text.write(delta);
    if (event is AgentCompleted || event is AgentFailed) {
      if (event case AgentFailed(:final reason, :final message)) {
        print('  ${agent.handle.id} failed: $reason $message');
      }
      if (!done.isCompleted) done.complete();
    }
  });
  final transcript = Transcript(
    id: TranscriptId.v7(),
    revision: 0,
    entries: [
      TranscriptEntry(
        id: TranscriptEntryId.v7(),
        role: Role.user,
        blocks: [
          TranscriptParagraphBlock(id: TranscriptBlockId.v7(), text: prompt),
        ],
      ),
    ],
  );
  expect(await agent.run(transcript), isA<RunAccepted>());
  await done.future;
  await events.cancel();
  return text.toString().trim();
}

void _writeIndex(String bestieDir, File model, String localId) {
  final index = ModelIndex(
    version: ModelIndex.currentVersion,
    models: [
      ModelIndexEntry(
        localId: localId,
        path: model.path,
        displayName: 'Qwen3 1.7B',
        profileId: ModelProfileId.qwen3,
        architecture: 'qwen3',
        fileType: 'Q4_K_M',
        sizeBytes: model.lengthSync(),
        trainedContextLength: 40960,
        reasoning: const ModelReasoningToggle(),
        defaultSampling: const ModelSamplingDefaults(),
        provenance: ModelScanned(root: model.parent.path),
        fingerprint: 'f157866c',
      ),
    ],
  );
  File(p.join(modelsDirFor(bestieDir, p.context), ModelIndex.fileName))
    ..createSync(recursive: true)
    ..writeAsStringSync(index.toJson());
}
