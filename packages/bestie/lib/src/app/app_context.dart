import 'dart:async';
import 'dart:ffi';
import 'dart:io' show Directory;

import 'package:agent_provider_remote/agent_provider_remote.dart';
import 'package:agent_repository/agent_repository.dart';
import 'package:agentic_terminal/agentic_terminal.dart';
import 'package:app_shell_use_case/app_shell_use_case.dart';
import 'package:app_terminal_environment_use_case/app_terminal_environment_use_case.dart';
import 'package:bestie/src/app/assets/app_assets.dart';
import 'package:bestie/src/app/assets/credits_loader.dart';
import 'package:bestie/src/app/models/agent_defaults.dart';
import 'package:bestie/src/app/models/app_metadata.dart';
import 'package:bestie/src/app/prompts/compaction_prompt_content_builder.dart';
import 'package:bestie/src/app/prompts/dynamic_system_prompt.dart';
import 'package:bestie/src/app/prompts/subagent_system_prompt_builder.dart';
import 'package:bestie/src/app/tools/process_host_builder.dart';
import 'package:bestie/src/app/tools/toolbox_builder.dart';
import 'package:bestie_chat_use_case/bestie_chat_use_case.dart';
import 'package:bestie_commands_use_case/bestie_commands_use_case.dart';
import 'package:bestie_config/bestie_config.dart';
import 'package:bestie_config_view/bestie_config_view.dart';
import 'package:bestie_mascot_use_case/bestie_mascot_use_case.dart';
import 'package:bestie_platform_abstractions/bestie_platform_abstractions.dart';
import 'package:bestie_platform_linux/bestie_platform_linux.dart';
import 'package:bestie_platform_macos/bestie_platform_macos.dart';
import 'package:bestie_platform_windows/bestie_platform_windows.dart';
import 'package:bestie_posix/bestie_posix.dart';
import 'package:bestie_provider_use_case/bestie_provider_use_case.dart';
import 'package:bestie_sandbox_use_case/bestie_sandbox_use_case.dart';
import 'package:bestie_shell_use_case/bestie_shell_use_case.dart';
import 'package:bestie_tools_use_case/bestie_tools_use_case.dart';
import 'package:bestie_ui/bestie_ui.dart';
import 'package:clock/clock.dart';
import 'package:config_repository/config_repository.dart';
import 'package:diagnostics/diagnostics.dart';
import 'package:file/file.dart' show FileSystem;
import 'package:files_data_source/files_data_source.dart';
import 'package:http/http.dart' as http;
import 'package:inference_openai_compat/inference_openai_compat.dart';
import 'package:intentions/intentions.dart';
import 'package:model_catalog_modelsdev/model_catalog_modelsdev.dart';
import 'package:openrouter_sdk/openrouter_sdk.dart' as openrouter;
import 'package:path/path.dart' as p;
import 'package:platform/platform.dart';
import 'package:platform_repository/platform_repository.dart';
import 'package:process_host/process_host.dart';
import 'package:provider_fireworks/provider_fireworks.dart';
import 'package:provider_openai_compat/provider_openai_compat.dart';
import 'package:provider_openrouter/provider_openrouter.dart';
import 'package:provider_repository/provider_repository.dart';
import 'package:sandbox_grant_store/sandbox_grant_store.dart';
import 'package:sandbox_linux/sandbox_linux.dart';
import 'package:sandbox_macos/sandbox_macos.dart';
import 'package:sandbox_repository/sandbox_repository.dart';
import 'package:sandbox_windows/sandbox_windows.dart';
import 'package:shell_repository/shell_repository.dart';
import 'package:tool_protocol/tool_protocol.dart';
import 'package:win32_dart/win32_dart.dart'
    show Capabilities, SidSucceeded, bestieReadCapabilityName, win32;

const String openRouterAppTitle = 'Bestie';
const String openRouterAppSite = 'https://hobbyfarm.ai';
const List<String> openRouterAppCategories = ['cli-agent'];

/// The constructed dependency graph for a running bestie process.
@model
class AppContext {
  const AppContext({
    required this.platform,
    required this.platformRepository,
    required this.terminalHost,
    required this.shellUserland,
    required this.httpClient,
    required this.providerRepository,
    required this.agentRepository,
    required this.shellRepository,
    required this.sandboxRepository,
    required this.userlandRepository,
    required this.configUseCase,
    required this.providerUseCase,
    required this.chatUseCase,
    required this.sandboxUseCase,
    required this.shellUseCase,
    required this.toolsUseCase,
    required this.commandsUseCase,
    required this.utilityToolsUseCase,
    required this.appTerminalEnvironmentUseCase,
    required this.appShellUseCase,
    required this.mascotUseCase,
    required this.configKeys,
    required this.configLayout,
    required this.appInfo,
    required this.credits,
    required this.toolDefinitions,
  });

  // Platform & host

  /// Pure platform configuration and resolved paths.
  final OSPlatform platform;

  /// Domain facade over platform-specific external systems.
  final OSPlatformRepository platformRepository;

  /// Spawns the embedded shell's terminal.
  final TerminalHost terminalHost;

  /// The resolved confined-shell userland (held for [start]'s provisioning).
  final ShellUserland shellUserland;

  // Repositories

  /// The hosted provider session: key, model, and the agents it hands out.
  /// Shared by every hosted-provider data source; closed on [dispose].
  final http.Client httpClient;

  final ProviderRepository providerRepository;

  /// Conversations and the agents that run them.
  final AgentRepository agentRepository;

  /// Live shell sessions.
  final ShellRepository shellRepository;

  /// Confinement of the agent shell's session.
  final SandboxRepository sandboxRepository;

  /// The confined shell's installed userland (coreutils links).
  final ShellUserlandRepository userlandRepository;

  // Use cases

  /// Reads and writes user configuration.
  final ConfigUseCase configUseCase;

  /// Configures the hosted provider from config and exposes its status.
  final ProviderUseCase providerUseCase;

  /// Drives conversations against the connected model.
  final ChatUseCase chatUseCase;

  /// Plans the session's confinement and reports how far along it is.
  final SandboxUseCase sandboxUseCase;

  /// Opens and closes shell sessions.
  final ShellUseCase shellUseCase;

  /// Routes every tool call to the feature that owns it, and owns the jobs
  /// those calls become.
  final ToolsUseCase toolsUseCase;

  /// The palette's catalog of every feature's contributed commands.
  final CommandsUseCase commandsUseCase;

  /// Owns the utility tools and the pool of workers that run them.
  final UtilityToolsUseCase utilityToolsUseCase;

  /// Owns bestie's process-level terminal overrides; reverted on [dispose].
  final AppTerminalEnvironmentUseCase appTerminalEnvironmentUseCase;

  /// Owns modal overlay visibility (config, palette); the view subscribes.
  final AppShellUseCase appShellUseCase;

  /// The mascot in the corner of the app.
  final MascotUseCase mascotUseCase;

  // Config schema

  /// The typed configuration key tree.
  final BestieConfigKeys configKeys;

  /// The configuration overlay's page/section layout.
  final ConfigLayout configLayout;

  // Static / view data

  /// Name, version, and description shown in the UI.
  final AppInfo appInfo;

  /// The bundled attribution document.
  final CreditsDocument credits;

  /// Every tool definition exposed to the primary agent.
  final ToolDefinitions toolDefinitions;

  /// Perform the app's initialization steps.
  Future<void> start() async {
    final provisioned = await userlandRepository.ensureProvisioned(
      shellUserland,
    );
    if (provisioned is ProvisionFailed) {
      Diagnostics.log('shell-userland', provisioned.reason);
    }
  }

  /// Tears down every owned service in dependency order.
  Future<void> dispose() async {
    await shellUseCase.dispose();
    await sandboxUseCase.dispose();
    await sandboxRepository.dispose();
    await shellRepository.dispose();
    await toolsUseCase.dispose();
    await utilityToolsUseCase.dispose();
    await chatUseCase.dispose();
    await providerUseCase.dispose();
    // save session
    await agentRepository.dispose();
    await providerRepository.dispose();
    httpClient.close();
    await configUseCase.dispose();
    await appShellUseCase.dispose();
    await appTerminalEnvironmentUseCase.dispose();
    await appTerminalEnvironmentUseCase.restore();
  }

  /// Builds every long-lived service the app needs.
  static Future<AppContext> initialize({
    required Platform hostPlatform,
    required FileSystem fileSystem,
    required Abi abi,
    required bool bundled,
    required OSPlatformRepository platformRepository,
    required AppTerminalEnvironmentUseCase appTerminalEnvironmentUseCase,
    Clock clock = const Clock(),
    String? directory,
  }) async {
    final platform = platformRepository.platform;
    final hostEnvironment = hostPlatform.environment;

    // Platform-specific services beyond the repository: the process host and
    // the terminal it spawns, the confined shell's userland, the editor
    // behind the `edit` tool, and the sandbox.
    final ProcessHostLocation processHostLocation;
    final ShellUserland shellUserland;
    final String editorPath;
    final SandboxRepository sandboxRepository;
    final SandboxPlatformModel sandboxModel;
    final ExecutableLinkDataSource linkDataSource;
    if (hostPlatform.isMacOS) {
      final dataSource = MacOSPlatformDataSource(
        platform: hostPlatform,
        fileSystem: fileSystem,
        abi: abi,
        bundled: bundled,
        assets: macOSAppAssets,
      );
      processHostLocation = PosixProcessHostLocation(
        spawnerBinaryPath: dataSource.resolveSpawnerPath(),
      );
      shellUserland = dataSource.resolveShellUserland();
      editorPath = dataSource.resolveEditorPath();
      sandboxRepository = SandboxRepository(
        SandboxMacos(fileSystem: fileSystem),
      );
      sandboxModel = SandboxPlatformModel.posix;
      linkDataSource = PosixExecutableLinkDataSource(fileSystem: fileSystem);
    } else if (hostPlatform.isLinux) {
      final dataSource = LinuxPlatformDataSource(
        platform: hostPlatform,
        fileSystem: fileSystem,
        abi: abi,
        bundled: bundled,
        assets: linuxAppAssets,
      );
      processHostLocation = PosixProcessHostLocation(
        spawnerBinaryPath: dataSource.resolveSpawnerPath(),
      );
      shellUserland = dataSource.resolveShellUserland();
      editorPath = dataSource.resolveEditorPath();
      sandboxRepository = SandboxRepository(
        SandboxLinux(fileSystem: fileSystem),
      );
      sandboxModel = SandboxPlatformModel.posix;
      linkDataSource = PosixExecutableLinkDataSource(fileSystem: fileSystem);
    } else if (hostPlatform.isWindows) {
      final dataSource = WindowsPlatformDataSource(
        platform: hostPlatform,
        fileSystem: fileSystem,
        abi: abi,
        bundled: bundled,
        assets: windowsAppAssets,
      );
      processHostLocation = WindowsProcessHostLocation(
        conptyLibraryPath: dataSource.resolveConsoleHost().libraryPath,
      );
      shellUserland = dataSource.resolveShellUserland();
      editorPath = dataSource.resolveEditorPath();

      // The confined shell reads through a broad-access capability SID; without
      // it the sandbox could confine but never grant reads, so fail fast rather
      // than spin up a worker for a sandbox that cannot do its job.
      final capabilitySid = _capabilitySidOf(bestieReadCapabilityName);
      if (capabilitySid == null) {
        throw StateError(
          'could not derive the bestie read-capability SID; the Windows '
          'sandbox cannot grant broad read access without it',
        );
      }

      sandboxModel = SandboxPlatformModel.windows;
      final readPolicy = SandboxReadPolicy(
        readRoots: [
          ...sandboxModel.systemReadRoots,
          ...sandboxModel.homeReadRoots(platform.homeDir),
          shellUserland.binDir,
          p.dirname(editorPath),
        ],
        holes: sandboxModel.deniedReadsFor(platform.homeDir),
        policyVersion: 1,
      );
      final worker = switch (await Win32SandboxWorker.spawn()) {
        SandboxWorkerCreateSucceeded(:final worker) => worker,
        SandboxWorkerCreateFailed(:final message) => throw StateError(
          'sandbox worker isolate failed to spawn: $message',
        ),
      };
      sandboxRepository = SandboxRepositoryForWindows(
        sandboxBackend: SandboxWindows(
          worker,
          bestieReadCapabilitySid: capabilitySid,
          // From source, the helper is the Dart VM re-running this script.
          helperExecutable: hostPlatform.resolvedExecutable,
          helperArguments: bundled
              ? const []
              : ['run', hostPlatform.script.toFilePath()],
        ),
        store: SandboxGrantStore(
          file: platform.sandboxesFile,
          fileSystem: fileSystem,
        ),
        bestieReadCapabilitySid: capabilitySid,
        readPolicy: readPolicy,
      );
      linkDataSource = WindowsExecutableLinkDataSource();
    } else {
      throw UnsupportedError(
        'Unsupported platform: ${hostPlatform.operatingSystem}',
      );
    }

    final processHost = buildProcessHost(processHostLocation);
    final terminalHost = ProcessHostTerminalHost(processHost);
    final userlandRepository = ShellUserlandRepository(
      linkDataSource: linkDataSource,
      fileSystem: fileSystem,
      processRunner: ProcessRunner(
        host: processHost,
        environment: hostEnvironment,
      ),
    );

    final configDataSource = ConfigDataSource(configFile: platform.configFile);
    final loaded = configDataSource.load();
    if (loaded is ConfigRecovered) {
      Diagnostics.log(
        'config',
        'recovered from a corrupt config; backup at ${loaded.backupPath}',
      );
    }
    final workingDirectory = directory ?? Directory.current.path;

    final tools = [
      ...utilityToolDefinitions,
      ...shellToolDefinitions.definitions,
      ...sandboxToolDefinitions.definitions,
    ];

    // Subagents can do everything except use other subagents.
    final subagentToolDefinitions = ToolDefinitions([...tools]);
    final toolDefinitions = ToolDefinitions([
      ...tools,
      ...subagentControlDefinitions.definitions,
    ]);

    final conversationStore = ConversationStore(
      conversationsDir: platform.conversationsDir,
      fileSystem: fileSystem,
    );

    final configSchema = buildConfigSchema(
      defaultSystemPrompt: systemPrompt,
      defaultTheme: appThemeDefault.name,
      availableThemes: appThemes.keys.toList(),
    );
    final parameters = configSchema.keys;
    final configLayout = configSchema.layout;
    const appInfo = AppInfo(
      version: AppMetadata.version,
      description: AppMetadata.description,
    );
    final credits = CreditsDocument(
      markdown: readCredits(fileSystem, platform),
    );
    final configRepository = ConfigRepository(dataSource: configDataSource);
    final configUseCase = ConfigUseCase(configRepository);

    final sandboxUseCase = SandboxUseCase(
      sandboxes: sandboxRepository,
      config: configRepository,
      configKeys: parameters.sandbox,
      sandboxModel: sandboxModel,
    );
    final sandboxPlan = sandboxUseCase.setupSandbox(
      workspaceRoot: workingDirectory,
      homeDir: platform.homeDir,
      tempDir: platform.tempDir,
      programRoots: [shellUserland.binDir, p.dirname(editorPath)],
    );

    final dynamicSystemPrompt = buildDynamicSystemPrompt(
      now: clock.now(),
      cwd: workingDirectory,
      platformNote: hostPlatform.isWindows && sandboxPlan is SandboxPlanned
          ? windowsSandboxNote
          : null,
    );

    final utilityToolsUseCase = buildUtilityTools(
      platform: platform,
      workingDirectory: workingDirectory,
      config: configRepository,
      configKeys: parameters.tools,
      editorPath: editorPath,
      processHost: processHostLocation,
      sandboxes: sandboxRepository,
    );

    final agentRepository = AgentRepository(
      configuration: AgentConfiguration(
        compactionRatio: configRepository.resolve(
          parameters.chat.memoryCompactionRatio.global,
        ),
        maxToolCallCharacters: configRepository.resolve(
          parameters.chat.maxToolCallCharacters.global,
        ),
      ),
      toolDefinitions: toolDefinitions,
      subagentToolDefinitions: subagentToolDefinitions,
      conversationStore: conversationStore,
      workingDirectory: workingDirectory,
      subagentSystemPromptBuilder: FixedSubagentSystemPromptBuilder(
        dynamicPortion: dynamicSystemPrompt,
      ),
      compactionPromptContentBuilder:
          const BestieCompactionPromptContentBuilder(),
    );

    final httpClient = http.Client();
    final modelCatalog = ModelsDevCatalog(
      client: httpClient,
      cacheFile: fileSystem.file(platform.modelCatalogCacheFile),
    );
    final providerRepository = ProviderRepository(
      factories: ProviderSessionFactories(
        providerFactory: (account) {
          if (account.descriptor.id == openRouterDescriptor.id) {
            return OpenRouterProvider(
              client: openrouter.OpenRouter(
                apiKey: account.apiKey,
                httpReferer: openRouterAppSite,
                appTitle: openRouterAppTitle,
                appCategories: openRouterAppCategories.toSet(),
              ),
              apiKey: account.apiKey,
              httpReferer: openRouterAppSite,
              appTitle: openRouterAppTitle,
              appCategories: openRouterAppCategories,
            );
          }
          final inference = OpenAiCompatProvider(
            descriptor: account.descriptor,
            baseUrl: account.resolvedBaseUrl!,
            apiKey: account.apiKey,
            client: httpClient,
          );
          if (account.descriptor.id != fireworksDescriptor.id) return inference;
          return FireworksProvider(
            inference: inference,
            apiKey: account.apiKey,
            client: httpClient,
            clock: clock,
          );
        },
        inferenceClientFactory: (endpoint) => OpenAiCompatInferenceClient(
          endpoint: endpoint,
          clientFactory: http.Client.new,
        ),
        agentProviderSpawner:
            ({
              required client,
              required modelId,
              required contextWindow,
              required maxAgents,
            }) => RemoteAgentProvider(
              client: client,
              options: RemoteProviderOptions(
                modelId: modelId,
                contextWindow: contextWindow,
                maxAgents: maxAgents,
              ),
            ),
      ),
      catalog: modelCatalog,
    );

    final providerUseCase = ProviderUseCase(
      config: configRepository,
      configKeys: parameters.provider,
      providerRepository: providerRepository,
      agentRepository: agentRepository,
    );

    final chatUseCase = ChatUseCase(
      providerRepository: providerRepository,
      agentRepository: agentRepository,
      config: configRepository,
      configKeys: parameters.chat,
      sampling: () => providerUseCase.sampling,
      dynamicSystemPrompt: dynamicSystemPrompt,
      homeDirectory: platform.homeDir,
    );

    final shellRepository = ShellRepository(
      host: terminalHost,
      files: FilesDataSource(
        fileSystem: fileSystem,
        workingDirectory: workingDirectory,
      ),
    );

    final shellEnvironment = ShellEnvironment(
      userland: shellUserland,
      hostEnvironment: hostEnvironment,
      homeDir: platform.homeDir,
    );

    final shellUseCase = ShellUseCase(
      repository: shellRepository,
      environment: shellEnvironment,
      config: configUseCase,
      configKeys: parameters.shell,
      sandboxes: sandboxRepository,
    );

    final toolsUseCase = ToolsUseCase(
      agents: agentRepository,
      responders: [
        utilityToolsUseCase,
        chatUseCase,
        shellUseCase,
        sandboxUseCase,
      ],
    );

    final appShellUseCase = AppShellUseCase();

    final mascotUseCase = MascotUseCase(
      config: configRepository,
      configKeys: parameters.mascot,
    );

    final commandsUseCase = CommandsUseCase(
      contributions: [
        providerUseCase,
        toolsUseCase,
        chatUseCase,
        shellUseCase,
        sandboxUseCase,
        appTerminalEnvironmentUseCase,
        appShellUseCase,
      ],
    );

    return AppContext(
      platform: platform,
      platformRepository: platformRepository,
      terminalHost: terminalHost,
      shellUserland: shellUserland,
      httpClient: httpClient,
      providerRepository: providerRepository,
      agentRepository: agentRepository,
      shellRepository: shellRepository,
      sandboxRepository: sandboxRepository,
      userlandRepository: userlandRepository,
      configUseCase: configUseCase,
      providerUseCase: providerUseCase,
      chatUseCase: chatUseCase,
      sandboxUseCase: sandboxUseCase,
      shellUseCase: shellUseCase,
      toolsUseCase: toolsUseCase,
      commandsUseCase: commandsUseCase,
      utilityToolsUseCase: utilityToolsUseCase,
      appTerminalEnvironmentUseCase: appTerminalEnvironmentUseCase,
      appShellUseCase: appShellUseCase,
      mascotUseCase: mascotUseCase,
      configKeys: parameters,
      configLayout: configLayout,
      appInfo: appInfo,
      credits: credits,
      toolDefinitions: toolDefinitions,
    );
  }
}

/// The SID Windows derives for the capability [name], or null when it cannot.
String? _capabilitySidOf(String name) {
  final derived = Capabilities(win32).sidFor(name);
  if (derived is! SidSucceeded) return null;
  try {
    return derived.sid.asString();
  } finally {
    derived.sid.close();
  }
}
