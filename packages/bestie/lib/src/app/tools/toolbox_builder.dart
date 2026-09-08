import 'dart:io' show Platform;

import 'package:arxiv_client/arxiv_client.dart';
import 'package:arxiv_tools/arxiv_tools.dart';
import 'package:bestie/src/app/tools/process_host_builder.dart';
import 'package:bestie_edit/bestie_edit.dart';
import 'package:bestie_platform_abstractions/bestie_platform_abstractions.dart';
import 'package:bestie_tools_use_case/bestie_tools_use_case.dart';
import 'package:calculator_tools/calculator_tools.dart';
import 'package:config_repository/config_repository.dart';
import 'package:curl_impersonate_dart/curl_impersonate_dart.dart';
import 'package:date_time_tools/date_time_tools.dart';
import 'package:edit_data_source/edit_data_source.dart';
import 'package:file/local.dart' show LocalFileSystem;
import 'package:files_data_source/files_data_source.dart';
import 'package:fs_tools/fs_tools.dart';
import 'package:metasearch_client/metasearch_client.dart';
import 'package:sandbox_repository/sandbox_repository.dart';
import 'package:web_fetch_tools/web_fetch_tools.dart';
import 'package:web_page_client/web_page_client.dart';
import 'package:web_search_tools/web_search_tools.dart';
import 'package:wikimedia_client/wikimedia_client.dart';
import 'package:wikipedia_tools/wikipedia_tools.dart';

/// Composes the feature for ordinary utility-style tools, backed by a pool of
/// isolate workers each running [buildToolbox].
UtilityToolsUseCase buildUtilityTools({
  required OSPlatform platform,
  required String workingDirectory,
  required ConfigRepository config,
  required ToolsConfigKeys configKeys,
  required String editorPath,
  required ProcessHostLocation processHost,
  required SandboxRepository sandboxes,
}) {
  final workerConfig = ToolWorkerConfig(
    workingDirectory: workingDirectory,
    curlLibraryPath: platform.curlLibraryPath,
    caCertPath: platform.caCertPath,
    editorPath: editorPath,
    processHost: processHost,
    toolCacheChars: config.resolve(configKeys.toolCacheChars.global),
  );

  return UtilityToolsUseCase(
    pool: ToolWorkerPool(
      spawnWorker: () => ToolIsolateWorker.spawn(
        config: workerConfig,
        toolboxFactory: buildToolbox,
      ),
      size: defaultConcurrentTools,
    ),
    config: config,
    configKeys: configKeys,
    sandboxes: sandboxes,
  );
}

/// Builds the tools a worker runs with, on the worker.
Toolbox buildToolbox(ToolWorkerConfig config) {
  final webClient = CurlImpersonateClient(
    libraryPath: config.curlLibraryPath,
    caCertPath: config.caCertPath,
  );
  final files = FilesDataSource(
    fileSystem: const LocalFileSystem(),
    workingDirectory: config.workingDirectory,
    headCacheChars: config.toolCacheChars,
  );

  return Toolbox(
    fsTools: FsTools(
      editor: EditDataSource(
        program: EditProgram(
          host: buildProcessHost(config.processHost),
          path: config.editorPath,
          environment: Platform.environment,
        ),
      ),
    ),
    webSearchTools: WebSearchTools(
      search: MetasearchClient(client: webClient),
      files: files,
    ),
    webFetchTools: WebFetchTools(
      pages: WebPageClient(client: webClient),
      files: files,
    ),
    wikipediaTools: WikipediaTools(
      wikipedia: WikimediaClient(client: webClient),
      files: files,
    ),
    arxivTools: ArxivTools(
      arxiv: ArxivSearchClient(client: webClient),
      files: files,
    ),
    calculator: const Calculator(),
    dateTime: const DateTimeTools(),
  );
}
