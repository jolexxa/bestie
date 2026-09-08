import 'package:tool_protocol/tool_protocol.dart'
    show ToolDefinition, ToolDefinitions;

/// The tool name an agent calls to ask the user for write access to a
/// directory outside the sandbox's writable roots.
const String requestWriteAccessName = 'request_write_access';

/// The model-facing definition of the write-access tool — its name, schema,
/// and labels. No tool implements it; the use case answers it.
const ToolDefinition requestWriteAccessDefinition = ToolDefinition(
  name: requestWriteAccessName,
  description:
      'Ask the user to let your commands and edits write to a directory. '
      'The sandbox only allows writes under the working directory, '
      'temp directories, and any granted directories. Toolchains that keep a '
      'cache or config elsewhere (a package cache, a global tool directory) '
      'fail with "permission denied" or "operation not permitted". Call this '
      'once for the narrowest directory that fixes it, say why in one '
      'sentence, and retry once it is granted. The user decides.',
  parameters: <String, Object?>{
    'type': 'object',
    'properties': <String, Object?>{
      'path': <String, Object?>{
        'type': 'string',
        'description':
            'The directory to write under. Absolute, or starting with "~" '
            'for the home directory.',
      },
      'reason': <String, Object?>{
        'type': 'string',
        'description':
            'One sentence for the user on what needs to write there.',
      },
    },
    'required': <String>['path', 'reason'],
  },
  onProgress: r'Asking to write to ${path}',
  onSuccess: r'Write access: ${path}',
  onError: r'Write access refused: ${path}',
);

/// The tools an agent uses to widen the sandbox.
final ToolDefinitions sandboxToolDefinitions = ToolDefinitions([
  requestWriteAccessDefinition,
]);
