import 'package:bestie_tools_use_case/src/definitions/utility_tool_names.dart';
import 'package:tool_protocol/tool_protocol.dart';

const webSearchDefinition = ToolDefinition(
  name: UtilityToolNames.webSearch,
  onProgress: r'Searching the web for ${query:quoted}',
  onSuccess: r'Searched the web for ${query:quoted}',
  onError: r'Web search failed for ${query:quoted}',
  description:
      'Searches the web across several search engines and returns a merged '
      'list of results with titles, URLs, and short snippets. Use web_fetch on '
      'at least one of the URLs returned.',
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

const newsSearchDefinition = ToolDefinition(
  name: UtilityToolNames.newsSearch,
  onProgress: r'Searching news for ${query:quoted}',
  onSuccess: r'Searched news for ${query:quoted}',
  onError: r'News search failed for ${query:quoted}',
  description:
      'Searches for recent news articles and returns results with titles, '
      'sources, dates, URLs, and snippets. Use web_fetch on at least one of '
      'the URLs returned.',
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
      'timelimit': <String, Object?>{
        'type': 'string',
        'enum': <String>['d', 'w', 'm'],
        'description':
            'Time filter: "d" for past day, "w" for past week, '
            '"m" for past month. Defaults to past week.',
      },
    },
    'required': <String>['query'],
  },
);
