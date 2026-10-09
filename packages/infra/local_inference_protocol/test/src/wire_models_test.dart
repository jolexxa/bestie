import 'dart:convert';

import 'package:local_inference_protocol/local_inference_protocol.dart';
import 'package:test/test.dart';

Map<String, Object?> _wire(String json) =>
    jsonDecode(json) as Map<String, Object?>;

const _entry = ModelIndexEntry(
  localId: 'qwen3-4b-1a2b3c4d',
  path: '/models/Qwen3-4B-Q4_K_M.gguf',
  displayName: 'Qwen3 4B',
  profileId: ModelProfileId.qwen3,
  architecture: 'qwen3',
  fileType: 'Q4_K_M',
  sizeBytes: 2500000000,
  parameterCount: 4000000000,
  trainedContextLength: 40960,
  reasoning: ModelReasoningToggle(),
  defaultSampling: ModelSamplingDefaults(
    temperature: 0.6,
    topK: 20,
    topP: 0.95,
    minP: 0,
  ),
  provenance: ModelDownloaded(
    repo: 'Qwen/Qwen3-4B-GGUF',
    revision: 'main',
    file: 'Qwen3-4B-Q4_K_M.gguf',
  ),
  fingerprint: '1a2b3c4d',
);

void main() {
  group('routes', () {
    test('name the bestie extensions', () {
      expect(bestieProtocolVersion, 1);
      expect(bestieAgentHeader, 'X-Bestie-Agent');
      expect(bestieOwnerHeader, 'X-Bestie-Owner');
      expect(bestieOwnerPidHeader, 'X-Bestie-Pid');
      expect(bestieChatTemplateKwargsField, 'chat_template_kwargs');
      expect(bestieEnableThinkingKey, 'enable_thinking');
      expect(bestieHealthPath, '/bestie/v1/health');
      expect(bestieSessionPath, '/bestie/v1/session');
      expect(bestieModelPath, '/bestie/v1/model');
      expect(bestieAgentPath('subagent:2'), '/bestie/v1/agents/subagent%3A2');
    });
  });

  group('HealthResponse', () {
    test('round-trips in snake case', () {
      const health = HealthResponse(
        protocolVersion: 1,
        serverVersion: '0.1.0',
        pid: 42,
      );

      expect(_wire(health.toJson()), {
        'protocol_version': 1,
        'server_version': '0.1.0',
        'pid': 42,
      });
      expect(HealthResponseMapper.fromJson(health.toJson()), health);
    });
  });

  group('SessionEvent', () {
    const events = <SessionEvent>[
      SessionOpened(ownerToken: 'token'),
      PoolSnapshotEvent(
        contextSize: 32768,
        maxAgents: 4,
        agents: [
          PoolAgent(
            id: 'primary:1',
            kind: AgentLeaseKind.primary,
            claimedTokens: 0,
            usedTokens: 1200,
          ),
          PoolAgent(
            id: 'subagent:2',
            kind: AgentLeaseKind.subagent,
            claimedTokens: 8192,
            usedTokens: 300,
          ),
        ],
        borrowedTokens: 8192,
      ),
      ModelStatusEvent(status: ModelUnloaded()),
      ModelStatusEvent(status: ModelFitting(localId: 'qwen3-4b-1a2b3c4d')),
      ModelStatusEvent(
        status: ModelLoading(localId: 'qwen3-4b-1a2b3c4d', progress: 0.5),
      ),
      ModelStatusEvent(
        status: ModelReady(
          localId: 'qwen3-4b-1a2b3c4d',
          contextSize: 32768,
          maxAgents: 4,
          deviceBytes: 3000000000,
        ),
      ),
      ModelStatusEvent(
        status: ModelFailed(
          localId: 'qwen3-4b-1a2b3c4d',
          reason: 'out of memory',
        ),
      ),
    ];

    test('round-trips every event through its base type', () {
      for (final event in events) {
        expect(SessionEventMapper.fromJson(event.toJson()), event);
      }
    });

    test('tags each event with its type', () {
      expect(
        [for (final event in events) _wire(event.toJson())['type']],
        [
          'session_opened',
          'pool_snapshot',
          'model_status',
          'model_status',
          'model_status',
          'model_status',
          'model_status',
        ],
      );
      expect(_wire(events[1].toJson())['borrowed_tokens'], 8192);
      expect(
        SessionEventMapper.fromJson(
          '{"type":"pool_snapshot","context_size":1,"max_agents":1,'
          '"agents":[]}',
        ),
        isA<PoolSnapshotEvent>().having(
          (pool) => pool.borrowedTokens,
          'borrowed tokens of an older server',
          0,
        ),
      );
      expect(_wire(events[1].toJson())['agents'], [
        {
          'id': 'primary:1',
          'kind': 'primary',
          'claimed_tokens': 0,
          'used_tokens': 1200,
        },
        {
          'id': 'subagent:2',
          'kind': 'subagent',
          'claimed_tokens': 8192,
          'used_tokens': 300,
        },
      ]);
      expect(_wire(events[5].toJson())['status'], {
        'state': 'ready',
        'local_id': 'qwen3-4b-1a2b3c4d',
        'context_size': 32768,
        'max_agents': 4,
        'device_bytes': 3000000000,
      });
    });

    test('round-trips a model status on its own', () {
      const status = ModelLoading(localId: 'qwen3', progress: 0.25);

      expect(_wire(status.toJson()), {
        'state': 'loading',
        'local_id': 'qwen3',
        'progress': 0.25,
      });
      expect(ModelStatusMapper.fromJson(status.toJson()), status);
    });
  });

  group('ServerError', () {
    test('round-trips a busy server with its status code', () {
      const busy = ServerBusy(ownerPid: 7);

      expect(ServerBusy.statusCode, 409);
      expect(_wire(busy.toJson()), {'error': 'server_busy', 'owner_pid': 7});
      expect(ServerErrorMapper.fromJson(busy.toJson()), busy);
    });
  });

  group('agent leases', () {
    test('round-trips an open request', () {
      const request = AgentOpenRequest(kind: AgentLeaseKind.subagent);

      expect(_wire(request.toJson()), {'kind': 'subagent'});
      expect(AgentOpenRequestMapper.fromJson(request.toJson()), request);
      expect(
        AgentOpenRequestMapper.fromJson(
          const AgentOpenRequest(kind: AgentLeaseKind.primary).toJson(),
        ),
        const AgentOpenRequest(kind: AgentLeaseKind.primary),
      );
    });

    test('round-trips every open result', () {
      const results = <AgentOpenResult>[
        AgentOpened(claimedTokens: 8192),
        AgentNoCapacity(),
        AgentInsufficientClaim(),
      ];

      expect(
        [for (final result in results) _wire(result.toJson())],
        [
          {'result': 'opened', 'claimed_tokens': 8192},
          {'result': 'no_capacity'},
          {'result': 'insufficient_claim'},
        ],
      );
      for (final result in results) {
        expect(AgentOpenResultMapper.fromJson(result.toJson()), result);
      }
    });
  });

  group('ModelLoadRequest', () {
    test('round-trips with and without a context cap', () {
      const capped = ModelLoadRequest(
        localId: 'qwen3-4b-1a2b3c4d',
        maxAgents: 4,
        contextCap: 16384,
      );
      const uncapped = ModelLoadRequest(
        localId: 'qwen3-4b-1a2b3c4d',
        maxAgents: 2,
      );

      expect(_wire(capped.toJson()), {
        'local_id': 'qwen3-4b-1a2b3c4d',
        'max_agents': 4,
        'context_cap': 16384,
      });
      expect(ModelLoadRequestMapper.fromJson(capped.toJson()), capped);
      expect(ModelLoadRequestMapper.fromJson(uncapped.toJson()), uncapped);
    });
  });

  group('InferenceLockFile', () {
    test('round-trips under its default file name', () {
      const lock = InferenceLockFile(pid: 42, port: 52100, protocolVersion: 1);

      expect(InferenceLockFile.fileName, 'inference.lock');
      expect(_wire(lock.toJson()), {
        'pid': 42,
        'port': 52100,
        'protocol_version': 1,
      });
      expect(InferenceLockFileMapper.fromJson(lock.toJson()), lock);
    });
  });

  group('ModelIndex', () {
    test('round-trips every reasoning capability and provenance', () {
      final index = ModelIndex(
        version: ModelIndex.currentVersion,
        models: [
          _entry,
          _entry.copyWith(
            localId: 'gpt-oss-20b-00ff00ff',
            parameterCount: null,
            reasoning: const ModelReasoningEfforts(
              efforts: ['low', 'medium', 'high'],
            ),
            defaultSampling: const ModelSamplingDefaults(),
            provenance: const ModelScanned(root: '/models'),
          ),
          _entry.copyWith(reasoning: const ModelReasoningNone()),
          _entry.copyWith(reasoning: const ModelReasoningAlways()),
          _entry.copyWith(
            provenance: const ModelDownloaded(repo: 'a/b', file: 'c.gguf'),
          ),
        ],
      );

      expect(ModelIndex.fileName, 'index.json');
      expect(ModelIndexMapper.fromJson(index.toJson()), index);
    });

    test('writes entries in snake case with tagged unions', () {
      expect(_wire(_entry.toJson()), {
        'local_id': 'qwen3-4b-1a2b3c4d',
        'path': '/models/Qwen3-4B-Q4_K_M.gguf',
        'display_name': 'Qwen3 4B',
        'profile_id': 'qwen3',
        'architecture': 'qwen3',
        'file_type': 'Q4_K_M',
        'size_bytes': 2500000000,
        'trained_context_length': 40960,
        'reasoning': {'kind': 'toggle'},
        'default_sampling': {
          'temperature': 0.6,
          'top_k': 20,
          'top_p': 0.95,
          'min_p': 0,
        },
        'provenance': {
          'source': 'downloaded',
          'repo': 'Qwen/Qwen3-4B-GGUF',
          'revision': 'main',
          'file': 'Qwen3-4B-Q4_K_M.gguf',
        },
        'fingerprint': '1a2b3c4d',
        'parameter_count': 4000000000,
      });
    });

    group('decode', () {
      test('reads every entry of a well-formed index', () {
        const index = ModelIndex(version: 1, models: [_entry]);

        expect(
          ModelIndex.decode(index.toJson()),
          isA<ModelIndexDecoded>()
              .having((decoded) => decoded.index, 'index', index)
              .having((decoded) => decoded.skippedEntries, 'skipped', 0),
        );
      });

      test('skips entries it cannot read and keeps the rest', () {
        final unknownProfile = _wire(_entry.toJson())
          ..['local_id'] = 'llama2-7b'
          ..['profile_id'] = 'llama2';
        final json = jsonEncode({
          'version': 1,
          'models': [
            unknownProfile,
            _wire(_entry.toJson()),
            'not an entry',
            {'local_id': 'half-written'},
          ],
        });

        expect(
          ModelIndex.decode(json),
          isA<ModelIndexDecoded>()
              .having((decoded) => decoded.index.models, 'models', [_entry])
              .having((decoded) => decoded.skippedEntries, 'skipped', 3),
        );
      });

      test('refuses text that is not JSON', () {
        expect(
          ModelIndex.decode('{nope'),
          isA<ModelIndexUndecodable>().having(
            (undecodable) => undecodable.message,
            'message',
            isNotEmpty,
          ),
        );
      });

      test('refuses JSON that is not an index', () {
        expect(
          ModelIndex.decode('{"version": 1}'),
          isA<ModelIndexUndecodable>(),
        );
        expect(ModelIndex.decode('[]'), isA<ModelIndexUndecodable>());
      });
    });
  });

  group('BestieModelList', () {
    test('round-trips the OpenAI listing with bestie fields', () {
      const list = BestieModelList(
        data: [
          BestieModel(
            id: 'qwen3-4b-1a2b3c4d',
            contextLength: 40960,
            created: 1700000000,
            bestie: BestieModelFacts(
              loaded: true,
              reasoning: ModelReasoningEfforts(efforts: ['low', 'high']),
              displayName: 'Qwen3 4B',
              fileType: 'Q4_K_M',
              sizeBytes: 2500000000,
            ),
          ),
        ],
      );

      expect(_wire(list.toJson()), {
        'object': 'list',
        'data': [
          {
            'id': 'qwen3-4b-1a2b3c4d',
            'object': 'model',
            'owned_by': 'bestie',
            'created': 1700000000,
            'context_length': 40960,
            'bestie': {
              'loaded': true,
              'reasoning': {
                'kind': 'efforts',
                'efforts': ['low', 'high'],
              },
              'display_name': 'Qwen3 4B',
              'file_type': 'Q4_K_M',
              'size_bytes': 2500000000,
            },
          },
        ],
      });
      expect(BestieModelListMapper.fromJson(list.toJson()), list);
    });
  });
}
