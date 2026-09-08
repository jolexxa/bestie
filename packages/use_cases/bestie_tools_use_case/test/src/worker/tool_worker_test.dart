import 'package:arxiv_tools/arxiv_tools.dart';
import 'package:bestie_platform_abstractions/bestie_platform_abstractions.dart';
import 'package:bestie_tools_use_case/bestie_tools_use_case.dart';
import 'package:calculator_tools/calculator_tools.dart';
import 'package:date_time_tools/date_time_tools.dart';
import 'package:fs_tools/fs_tools.dart';
import 'package:isolate_worker/isolate_worker.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';
import 'package:tool_protocol/tool_protocol.dart';
import 'package:web_fetch_tools/web_fetch_tools.dart';
import 'package:web_search_tools/web_search_tools.dart';
import 'package:wikipedia_tools/wikipedia_tools.dart';

class _MockFsTools extends Mock implements FsTools {}

class _MockWebSearchTools extends Mock implements WebSearchTools {}

class _MockWebFetchTools extends Mock implements WebFetchTools {}

class _MockWikipediaTools extends Mock implements WikipediaTools {}

class _MockArxivTools extends Mock implements ArxivTools {}

/// Built on the far side, so the tools that would reach a disk or a network are
/// stand-ins and only the two that need neither are real.
///
/// Top-level because that is the whole constraint being proved: a worker
/// receives a copy of its handler, and only a reference to shared program code
/// survives that trip.
Toolbox buildTestToolbox(ToolWorkerConfig config) => Toolbox(
  fsTools: _MockFsTools(),
  webSearchTools: _MockWebSearchTools(),
  webFetchTools: _MockWebFetchTools(),
  wikipediaTools: _MockWikipediaTools(),
  arxivTools: _MockArxivTools(),
  calculator: const Calculator(),
  dateTime: const DateTimeTools(),
);

final class _ThrowingSpawner implements IsolateSpawner {
  const _ThrowingSpawner();

  @override
  Future<SpawnedIsolate> spawn<Message>(
    void Function(Message message) entryPoint,
    Message message, {
    String? debugName,
  }) async {
    throw StateError('no isolates left');
  }
}

const _config = ToolWorkerConfig(
  workingDirectory: '/work',
  curlLibraryPath: '/curl',
  caCertPath: '/ca.pem',
  editorPath: '/bestie_edit',
  processHost: PosixProcessHostLocation(spawnerBinaryPath: '/spawner'),
);

ToolWorkRequest _request({
  required String toolName,
  Map<String, Object?> arguments = const {},
}) => ToolWorkRequest(
  ToolCallInvocation(
    conversationId: 'conversation',
    agentId: 'agent',
    callId: 'call-1',
    toolName: toolName,
    outputPath: 'output',
    maxOutputChars: 4000,
    arguments: arguments,
  ),
);

Future<ToolWorker> spawnWorker() async {
  final result = await ToolIsolateWorker.spawn(
    config: _config,
    toolboxFactory: buildTestToolbox,
  );
  return (result as ToolWorkerCreated).worker;
}

void main() {
  group('spawning', () {
    test('reports why no worker could be started', () async {
      final result = await ToolIsolateWorker.spawn(
        config: _config,
        toolboxFactory: buildTestToolbox,
        isolateSpawner: const _ThrowingSpawner(),
      );

      expect(
        (result as ToolWorkerCreateFailed).message,
        contains('no isolates left'),
      );
    });
  });

  group('over a real isolate', () {
    test('carries a call out and its outcome back', () async {
      final worker = await spawnWorker();
      addTearDown(worker.terminate);

      final outcome = await worker.run(
        _request(
          toolName: 'calculator',
          arguments: const {'expression': '2 + 40'},
        ),
      );

      expect((outcome as JobSucceeded).content, '42');
    });

    test('answers more than one call on the same worker', () async {
      final worker = await spawnWorker();
      addTearDown(worker.terminate);

      final first = await worker.run(
        _request(
          toolName: 'calculator',
          arguments: const {'expression': '1 + 1'},
        ),
      );
      final second = await worker.run(
        _request(
          toolName: 'calculator',
          arguments: const {'expression': '3 * 3'},
        ),
      );

      expect((first as JobSucceeded).content, '2');
      expect((second as JobSucceeded).content, '9');
    });

    test('brings back a failure as the outcome, not a throw', () async {
      final worker = await spawnWorker();
      addTearDown(worker.terminate);

      final outcome = await worker.run(_request(toolName: 'nonesuch'));

      expect((outcome as JobFailed).message, contains('No such tool'));
    });

    test('fails a call made after it was terminated', () async {
      final worker = await spawnWorker();
      await worker.terminate();

      final outcome = await worker.run(
        _request(
          toolName: 'calculator',
          arguments: const {'expression': '1 + 1'},
        ),
      );

      expect(outcome, isA<JobFailed>());
    });
  });
}
