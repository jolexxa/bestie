// A smoke test reports what it saw.
// ignore_for_file: avoid_print
@Tags(['integration'])
library;

import 'dart:async';
import 'dart:io';

import 'package:agent_provider_protocol/agent_provider_protocol.dart';
import 'package:agent_provider_remote/agent_provider_remote.dart';
import 'package:bestie_platform_abstractions/bestie_platform_abstractions.dart';
import 'package:file/local.dart';
import 'package:http/http.dart' as http;
import 'package:inference_openai_compat/inference_openai_compat.dart';
import 'package:inference_protocol/inference_protocol.dart';
import 'package:local_inference_client/local_inference_client.dart';
import 'package:local_inference_protocol/local_inference_protocol.dart';
import 'package:path/path.dart' as p;
import 'package:provider_protocol/provider_protocol.dart';
import 'package:test/test.dart';

/// Starts the real server from source against a scratch bestie directory
/// whose index names one GGUF, then drives it the way bestie does.
/// Run with `dart test --run-skipped -t integration`; `BESTIE_SMOKE_GGUF`
/// overrides the model.
void main() {
  final home = Platform.environment['HOME'] ?? '';
  final model = File(
    Platform.environment['BESTIE_SMOKE_GGUF'] ??
        '$home/Dropbox/AI/models/Qwen3-1.7B-Q4_K_M.gguf',
  );
  const localId = 'qwen3-1.7b-q4_k_m-f157866c';
  const descriptor = ProviderDescriptor(
    id: 'local',
    displayName: 'Local models',
    requiresApiKey: false,
    dialect: InferenceDialect.bestie,
  );
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
      _writeIndex(bestieDir.path, model, localId);
      print('bestie dir: ${bestieDir.path}');

      LocalInferenceClient clientFor(int pid) => LocalInferenceClient(
        client: http.Client(),
        sessionClientFactory: http.Client.new,
        fileSystem: const LocalFileSystem(),
        lockFile: inferenceLockFileFor(bestieDir.path, p.context),
        indexFile: p.join(
          modelsDirFor(bestieDir.path, p.context),
          ModelIndex.fileName,
        ),
        launch: LocalServerLaunch(
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
      );

      final first = clientFor(pid);
      first.connectionChanges.listen((state) => print('[1] $state'));
      final provider = first.provider(
        descriptor: descriptor,
        options: () => const LocalProviderOptions(),
      );

      final listed = await provider.models();
      final models = (listed as ProviderModelsListed).models;
      for (final entry in models) {
        print(
          'model ${entry.id}: ${entry.name}, ${entry.contextLength} ctx, '
          'reasoning ${entry.reasoning}',
        );
      }
      expect(models.single.id, localId);

      final activation = provider.activate(
        ModelActivationRequest(
          modelId: localId,
          contextWindow: models.single.contextLength!,
          maxAgents: 3,
        ),
      );
      final steps = <String>[];
      activation.progress.listen(
        (progress) => steps.add('${(progress * 100).round()}%'),
      );
      final activated = await activation.result;
      print('load progress: ${steps.join(' ')}');
      print('activated: $activated');
      final ModelActivated(:contextWindow, :endpoint) =
          activated as ModelActivated;
      print('connection: ${first.connection}');
      expect(first.connection, isA<LocalServerAttached>());

      print('endpoint: ${endpoint.baseUrl} ${endpoint.headers.keys}');
      final sessions = provider.openSessions(contextWindow: contextWindow);
      final reports = <AgentPoolReport>[];
      sessions.pool.listen(reports.add);
      final agents = RemoteAgentProvider(
        client: OpenAiCompatInferenceClient(
          endpoint: endpoint,
          clientFactory: http.Client.new,
        ),
        sessions: sessions,
        options: RemoteProviderOptions(
          modelId: localId,
          contextWindow: contextWindow,
          maxAgents: 3,
          maxOutputTokens: 96,
        ),
      );

      final primary =
          (await agents.startPrimary(config: _config) as StartPrimaryStarted)
              .agent;
      final subagent =
          (await agents.startSubagent(config: _config, label: 'helper')
                  as StartSubagentStarted)
              .agent;
      print(
        'pool: ${reports.last.contextSize} ctx, '
        '${reports.last.reservedTokens} reserved, ${reports.last.agents}',
      );

      final turns = await Future.wait([
        _runTurn(primary, 'Name one primary color. One word.'),
        _runTurn(subagent, 'Name one planet. One word.'),
      ]);
      print('primary said: ${turns[0]}');
      print('subagent said: ${turns[1]}');
      expect(turns, everyElement(isNotEmpty));

      final second = clientFor(pid + 1);
      final busy = await second.attach();
      print(
        'second bestie: $busy (ownerPid ${(busy as LocalServerBusy).ownerPid})',
      );
      expect(busy.ownerPid, pid);

      await agents.dispose();
      await first.close();
      final third = clientFor(pid + 2);
      final freed = await third.attach();
      print('after the first closed: $freed');
      expect(freed, isA<LocalServerAttached>());
      final status = await http.get(
        Uri.parse(
          'http://127.0.0.1:${(freed as LocalServerAttached).port}'
          '$bestieModelPath',
        ),
      );
      print('model status: ${status.body}');

      final lockFile = File(inferenceLockFileFor(bestieDir.path, p.context));
      int serverPid() =>
          InferenceLockFileMapper.fromJson(lockFile.readAsStringSync()).pid;
      final pids = [serverPid()];
      for (var round = 0; round < 3; round++) {
        await third.release();
        final again = await third.attach();
        print('re-picked after a release: $again (pid ${serverPid()})');
        expect(again, isA<LocalServerAttached>());
        expect(
          await third.load(
            const ModelLoadRequest(localId: localId, maxAgents: 1),
          ),
          isA<ModelLoaded>(),
        );
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
