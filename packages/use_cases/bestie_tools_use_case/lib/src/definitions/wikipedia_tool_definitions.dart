import 'package:bestie_tools_use_case/src/definitions/utility_tool_names.dart';
import 'package:tool_protocol/tool_protocol.dart';

const wikipediaSearchDefinition = ToolDefinition(
  name: UtilityToolNames.wikipediaSearch,
  onProgress: r'Searching Wikipedia for ${query:quoted}',
  onSuccess: r'Searched Wikipedia for ${query:quoted}',
  onError: r'Wikipedia search failed for ${query:quoted}',
  description:
      'Searches Wikipedia for topics matching a query and returns results '
      'with titles, descriptions, and Wikipedia URLs.',
  parameters: <String, Object?>{
    'type': 'object',
    'properties': <String, Object?>{
      'query': <String, Object?>{
        'type': 'string',
        'description': 'The search query.',
      },
      'max_results': <String, Object?>{
        'type': 'integer',
        'description': 'Maximum number of results to return (default: 5).',
      },
    },
    'required': <String>['query'],
  },
);
