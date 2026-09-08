import 'package:bestie_tools_use_case/src/definitions/utility_tool_names.dart';
import 'package:tool_protocol/tool_protocol.dart';

const arxivSearchDefinition = ToolDefinition(
  name: UtilityToolNames.arxivSearch,
  onProgress: r'Searching arXiv for ${query:quoted}',
  onSuccess: r'Searched arXiv for ${query:quoted}',
  onError: r'arXiv search failed for ${query:quoted}',
  description:
      'Searches arXiv for academic / research papers matching a query and '
      "returns results with titles, authors, dates, url's, and abstracts.",
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
      'category': <String, Object?>{
        'type': 'string',
        'description':
            'Optional arXiv category filter (e.g. cs.AI, math.AG, '
            'physics.gen-ph).',
      },
    },
    'required': <String>['query'],
  },
);
