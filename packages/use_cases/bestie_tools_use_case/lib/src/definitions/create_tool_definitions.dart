import 'package:bestie_tools_use_case/src/definitions/utility_tool_names.dart';
import 'package:tool_protocol/tool_protocol.dart';

const createDefinition = ToolDefinition(
  name: UtilityToolNames.create,
  onProgress: r'Creating ${path:basename}',
  onSuccess: r'Created ${path:basename}',
  onError: r'Failed to create ${path:basename}',
  description:
      'Creates a new file with the given contents, making any missing parent '
      'directories on the way. Fails if something already exists at the path; '
      'change an existing file with the edit tool instead.',
  parameters: <String, Object?>{
    'type': 'object',
    'properties': <String, Object?>{
      'path': <String, Object?>{
        'type': 'string',
        'description': 'Path of the file to create.',
      },
      'contents': <String, Object?>{
        'type': 'string',
        'description': 'The whole text of the new file.',
      },
    },
    'required': <String>['path', 'contents'],
  },
);
