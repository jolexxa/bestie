import 'package:bestie_tools_use_case/src/definitions/utility_tool_names.dart';
import 'package:tool_protocol/tool_protocol.dart';

const webFetchDefinition = ToolDefinition(
  name: UtilityToolNames.webFetch,
  onProgress: r'Fetching ${url:host}',
  onSuccess: r'Fetched ${url:host}',
  onError: r'Failed to fetch ${url:host}',
  description:
      'Fetches a web page and extracts its main content as clean, '
      'readable text. The whole page is written to a file, so a long one can '
      "be paged from bash with sed -n 'A,Bp'.",
  parameters: <String, Object?>{
    'type': 'object',
    'properties': <String, Object?>{
      'url': <String, Object?>{
        'type': 'string',
        'description': 'The URL of the web page to fetch.',
      },
    },
    'required': <String>['url'],
  },
);
