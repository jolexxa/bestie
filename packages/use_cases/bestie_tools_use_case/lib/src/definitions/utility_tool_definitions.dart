import 'package:bestie_tools_use_case/src/definitions/arxiv_tool_definitions.dart';
import 'package:bestie_tools_use_case/src/definitions/compute_tool_definitions.dart';
import 'package:bestie_tools_use_case/src/definitions/create_tool_definitions.dart';
import 'package:bestie_tools_use_case/src/definitions/edit_tool_definitions.dart';
import 'package:bestie_tools_use_case/src/definitions/web_fetch_tool_definitions.dart';
import 'package:bestie_tools_use_case/src/definitions/web_search_tool_definitions.dart';
import 'package:bestie_tools_use_case/src/definitions/wikipedia_tool_definitions.dart';
import 'package:tool_protocol/tool_protocol.dart';

/// Every utility tool the app offers, in the order a model is shown them.
///
/// A constant, so what an agent may call is known before anything is built.
const utilityToolDefinitions = <ToolDefinition>[
  createDefinition,
  editDefinition,
  webSearchDefinition,
  newsSearchDefinition,
  webFetchDefinition,
  wikipediaSearchDefinition,
  arxivSearchDefinition,
  calculatorDefinition,
  dateTimeDefinition,
];
