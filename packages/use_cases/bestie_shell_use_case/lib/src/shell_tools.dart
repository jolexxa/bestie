import 'package:tool_protocol/tool_protocol.dart'
    show ToolDefinition, ToolDefinitions;

/// The tool name an agent calls to run a command in a shell.
const String bashName = 'bash';

/// The tool name an agent calls to read back what a shell command printed.
const String bashReadName = 'bash_read';

/// The model-facing definition of the shell tool — its name, schema, and
/// labels. No tool implements it; the use case answers it.
const ToolDefinition bashDefinition = ToolDefinition(
  name: bashName,
  description:
      'Run a command in a real terminal and return what it printed. Only the '
      'end of long output comes back. A command still running after a few '
      'seconds keeps going in the background and reports when it finishes. '
      'Read the full output with $bashReadName.',
  parameters: <String, Object?>{
    'type': 'object',
    'properties': <String, Object?>{
      'command': <String, Object?>{
        'type': 'string',
        'description': 'The command line to run, as a shell would read it.',
      },
    },
    'required': <String>['command'],
  },
  onProgress: r'Running ${command}',
  onSuccess: r'Ran ${command}',
  onError: r'Failed to run ${command}',
  onBackgrounded: r'Continuing in background: ${command}',
  onJobSuccess: r'Finished: ${command}',
  onJobError: r'Failed: ${command}',
);

/// The model-facing definition of the shell paging tool.
const ToolDefinition bashReadDefinition = ToolDefinition(
  name: bashReadName,
  description: 'Read what a $bashName call printed, a page at a time.',
  parameters: <String, Object?>{
    'type': 'object',
    'properties': <String, Object?>{
      'id': <String, Object?>{
        'type': 'string',
        'description': 'The $bashName call id.',
      },
      'offset': <String, Object?>{
        'type': 'integer',
        'description':
            'Character to carry on from. Each page says the next one.',
      },
    },
    'required': <String>['id'],
  },
  onProgress: r'Reading output of ${id}',
  onSuccess: r'Read output of ${id}',
  onError: r'Failed to read output of ${id}',
);

/// The tools an agent uses to run commands and read back what they printed.
final ToolDefinitions shellToolDefinitions = ToolDefinitions([
  bashDefinition,
  bashReadDefinition,
]);
