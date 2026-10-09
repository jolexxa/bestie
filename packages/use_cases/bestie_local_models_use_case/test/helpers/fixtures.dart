import 'package:bestie_local_models_use_case/src/local_models_operations.dart';
import 'package:bestie_platform_abstractions/bestie_platform_abstractions.dart';
import 'package:command_protocol/command_protocol.dart';
import 'package:local_inference_protocol/local_inference_protocol.dart';
import 'package:local_models_repository/local_models_repository.dart';
import 'package:local_server_repository/local_server_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider_protocol/provider_protocol.dart' show ProviderFailure;

final class MockLocalModelsOperations extends Mock
    implements LocalModelsOperations {}

const homeDir = '/home/joanna';

/// The platform every test runs against, so paths read the same on any host.
final linuxPlatform = LinuxPlatform(
  architecture: OSArchitecture.linuxX64,
  homeDir: homeDir,
  tempDir: '/tmp',
  workingDirectory: '/work',
  bestieDir: '$homeDir/.bestie',
  configFile: '$homeDir/.bestie/bestie.json',
  conversationsDir: '$homeDir/.bestie/conversations',
  curlLibraryPath: '/opt/libcurl.so',
  caCertPath: '/opt/cacert.pem',
  creditsPath: '/opt/CREDITS.md',
  serverExecutable: const ProgramCommand(executable: '/opt/bestie_server'),
);

const int gigabyte = 1000 * 1000 * 1000;

SupportedModel supportedModel({
  String id = 'qwen3-8b',
  String displayName = 'Qwen 3 8B',
  String path = '$homeDir/.bestie/models/qwen3-8b-q4_k_m.gguf',
  int sizeBytes = 4680000000,
  ModelSource source = const DownloadedSource(
    downloadId: 'lmstudio-community/Qwen3-8B-GGUF:Qwen3-8B-Q4_K_M.gguf',
    repo: 'lmstudio-community/Qwen3-8B-GGUF',
    file: 'Qwen3-8B-Q4_K_M.gguf',
  ),
  int? parameterCount = 8190000000,
  ModelSamplingDefaults sampling = const ModelSamplingDefaults(
    temperature: 0.6,
    topP: 0.95,
    topK: 20,
  ),
}) => SupportedModel(
  id: id,
  path: path,
  displayName: displayName,
  sizeBytes: sizeBytes,
  fingerprint: '3fa9c2d1',
  source: source,
  profile: ModelProfileId.qwen3,
  architecture: 'qwen3',
  quant: QuantType.q4KMedium,
  contextLength: 40960,
  detectedReasoning: const ModelReasoningToggle(),
  sampling: sampling,
  parameterCount: parameterCount,
);

UnsupportedModel unsupportedModel({
  String id = 'granite',
  ModelSource source = const ScannedSource(root: '$homeDir/models'),
  UnsupportedReason reason = const ArchitectureUnsupported('granitehybrid'),
}) => UnsupportedModel(
  id: id,
  path: '$homeDir/models/granite-4.0-h-micro.gguf',
  displayName: 'granite-4.0-h-micro',
  sizeBytes: 1970000000,
  fingerprint: '77aa0011',
  source: source,
  reason: reason,
);

ModelDownload modelDownload({
  String id = 'openai/gpt-oss-20b-GGUF:gpt-oss-20b-MXFP4.gguf',
  String repo = 'openai/gpt-oss-20b-GGUF',
  int totalBytes = 11280000000,
  ModelDownloadStatus status = const DownloadTransferringStatus(
    receivedBytes: 5640000000,
    speedBytesPerSecond: 48300000,
  ),
}) => ModelDownload(
  id: id,
  repo: repo,
  quant: 'MXFP4',
  totalBytes: totalBytes,
  status: status,
);

RepoQuant repoQuant({
  String label = 'Q4_K_M',
  QuantType type = QuantType.q4KMedium,
  int sizeBytes = 4970000000,
  String repo = 'lmstudio-community/gemma-4-E4B-it-GGUF',
}) => RepoQuant(
  repo: repo,
  label: label,
  type: type,
  files: [
    RepoFile(
      path: 'gemma-4-E4B-it-$label.gguf',
      url: Uri.parse('https://huggingface.co/$repo/gemma-4-E4B-it-$label.gguf'),
      sizeBytes: sizeBytes,
    ),
  ],
  inLibrary: false,
);

const gemmaRepo = RepoSummary(
  repo: 'lmstudio-community/gemma-4-E4B-it-GGUF',
  downloads: 988000,
  likes: 287,
  architecture: 'gemma4',
  parameterCount: 7500000000,
);

const readyLibrary = ModelLibrary(
  status: LibraryReady(),
  downloadsStatus: DownloadsReady(),
);

ServerServing serving({
  String localId = 'qwen3-8b',
  LocalAgentPool? pool,
}) => ServerServing(
  localId: localId,
  contextSize: 32768,
  maxAgents: 4,
  deviceBytes: 6100000000,
  pool: pool,
);

String spansText(Iterable<PaneSpan> spans) =>
    spans.map((span) => span.text).join();

String noteText(PaneNote note) => spansText(note.spans);

PaneAction actionOf(PaneRow row, PaneKey key) =>
    row.actions.firstWhere((action) => action.key == key);

List<String> actionLabels(PaneRow row) => [
  for (final action in row.actions) action.label,
];

PaneRow rowById(PaneContent content, String id) =>
    content.rows.firstWhere((row) => row.id == id);

/// Wires [operations] with a library, server and model in use that never
/// change unless the test pushes new values through the returned streams.
void stubOperations(
  MockLocalModelsOperations operations, {
  Stream<ModelLibrary>? library,
  ModelLibrary currentLibrary = readyLibrary,
  Stream<LocalServerStatus>? server,
  Stream<String?>? inUseIds,
  String? inUseId,
  Stream<ProviderFailure?>? failures,
  int memoryBytes = 24 * gigabyte,
  int freeMemoryBytes = 18 * gigabyte,
}) {
  when(() => operations.library).thenAnswer(
    (_) => library ?? Stream.value(currentLibrary),
  );
  when(() => operations.currentLibrary).thenReturn(currentLibrary);
  when(() => operations.server).thenAnswer(
    (_) => server ?? Stream.value(const ServerIdle()),
  );
  when(() => operations.inUseIds).thenAnswer(
    (_) => inUseIds ?? Stream.value(inUseId),
  );
  when(() => operations.inUseId).thenReturn(inUseId);
  when(() => operations.failures).thenAnswer(
    (_) => failures ?? Stream.value(null),
  );
  when(() => operations.shorten(any())).thenAnswer(
    (invocation) => linuxPlatform.paths.shortenHome(
      invocation.positionalArguments.single as String,
    ),
  );
  when(() => operations.memoryBytes).thenReturn(memoryBytes);
  when(() => operations.freeMemoryBytes).thenReturn(freeMemoryBytes);
}
