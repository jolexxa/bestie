import 'package:bestie_tools_use_case/src/definitions/utility_tool_names.dart';
import 'package:tool_protocol/tool_protocol.dart';

const editDefinition = ToolDefinition(
  name: UtilityToolNames.edit,
  onProgress: r'Editing ${path:basename}',
  onSuccess: r'Edited ${path:basename}',
  onError: r'Failed to edit ${path:basename}',
  description:
      'Replaces text in an existing file. old_string must match the file '
      'exactly, whitespace and indentation included, and must occur exactly '
      'once unless replace_all is set; read the file first and copy the text '
      'from what you were shown. Only files inside the working directory can '
      'be changed. Create new files with the create tool instead.',
  parameters: <String, Object?>{
    'type': 'object',
    'properties': <String, Object?>{
      'path': <String, Object?>{
        'type': 'string',
        'description': 'Path to the file to change.',
      },
      'old_string': <String, Object?>{
        'type': 'string',
        'description':
            'The exact text to replace. Include enough surrounding lines '
            'to make it unique in the file.',
      },
      'new_string': <String, Object?>{
        'type': 'string',
        'description': 'The text to put in its place.',
      },
      'replace_all': <String, Object?>{
        'type': 'boolean',
        'description':
            'Replace every occurrence of old_string rather than requiring '
            'exactly one. Defaults to false.',
      },
    },
    'required': <String>['path', 'old_string', 'new_string'],
  },
);
