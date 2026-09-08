import 'package:arxiv_tools/arxiv_tools.dart';
import 'package:bestie_platform_abstractions/bestie_platform_abstractions.dart';
import 'package:bestie_tools_use_case/src/utility_tools_use_case.dart';
import 'package:calculator_tools/calculator_tools.dart';
import 'package:date_time_tools/date_time_tools.dart';
import 'package:files_data_source/files_data_source.dart';
import 'package:fs_tools/fs_tools.dart';
import 'package:intentions/intentions.dart';
import 'package:web_fetch_tools/web_fetch_tools.dart';
import 'package:web_search_tools/web_search_tools.dart';
import 'package:wikipedia_tools/wikipedia_tools.dart';

/// Everything a tool call may reach for, assembled together.
@PartOf(UtilityToolsUseCase)
final class Toolbox {
  const Toolbox({
    required this.fsTools,
    required this.webSearchTools,
    required this.webFetchTools,
    required this.wikipediaTools,
    required this.arxivTools,
    required this.calculator,
    required this.dateTime,
  });

  final FsTools fsTools;
  final WebSearchTools webSearchTools;
  final WebFetchTools webFetchTools;
  final WikipediaTools wikipediaTools;
  final ArxivTools arxivTools;
  final Calculator calculator;
  final DateTimeTools dateTime;
}

/// What a [Toolbox] needs to exist, reduced to values that survive a trip to
/// another isolate.
@model
final class ToolWorkerConfig {
  const ToolWorkerConfig({
    required this.workingDirectory,
    required this.curlLibraryPath,
    required this.caCertPath,
    required this.editorPath,
    required this.processHost,
    this.toolCacheChars = defaultToolCacheChars,
  });

  final String workingDirectory;
  final String curlLibraryPath;
  final String caCertPath;

  /// The program behind the `edit` tool.
  final String editorPath;

  /// What spawning that program takes on this platform.
  final ProcessHostLocation processHost;

  /// Characters of a stored tool output's beginning the worker's store
  /// caches.
  final int toolCacheChars;
}

/// Builds a [Toolbox] wherever it is called, which for the production factory
/// is inside the worker. Must be a top-level or static function to survive
/// the handler's copy to the worker.
typedef ToolboxFactory = Toolbox Function(ToolWorkerConfig config);
