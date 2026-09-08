import 'package:tool_protocol/tool_protocol.dart'
    show ToolDefinition, ToolDefinitions;

/// The tool name an agent calls to delegate work to a subagent.
const String subagentName = 'subagent';

/// The tool name an agent calls to pull a finished subagent's output.
const String subagentReadName = 'subagent_read';

/// The `include` argument selecting a subagent's working history.
const String subagentTranscriptView = 'transcript';

/// The model-facing definition of the subagent tool: the single source of its
/// name, schema, and label templates.
///
/// No tool implements it. Spawning needs the agent provider and the session
/// roster, so it is advertised here and answered by the use case.
const ToolDefinition subagentDefinition = ToolDefinition(
  name: subagentName,
  description:
      'Delegate a self-contained subtask to a subagent that works '
      'independently — with its own tools — and reports back. This '
      'call returns immediately with a dispatch acknowledgement, NOT the '
      'report — the subagent runs in the background and its report arrives '
      'shortly after as a follow-up message. You are free to keep working, '
      'answer the user, and dispatch more subagents while they run.',
  parameters: <String, Object?>{
    'type': 'object',
    'properties': <String, Object?>{
      'prompt': <String, Object?>{
        'type': 'string',
        'description': 'The complete, standalone task for the subagent.',
      },
      'title': <String, Object?>{
        'type': 'string',
        'description': 'A short label for the subagent, shown in the UI.',
      },
    },
    'required': <String>['prompt'],
  },
  onProgress: r'Starting subagent: ${title}',
  onSuccess: r'Started subagent: ${title}',
  onError: r'Could not start subagent: ${title}',
  onBackgrounded: r'Subagent working in background: ${title}',
  onJobSuccess: r'Subagent finished: ${title}',
  onJobError: r'Subagent failed: ${title}',
);

/// The model-facing definition of the read tool. Like spawn, no tool
/// implements it — it reads stored transcripts, which the domain owns.
const ToolDefinition subagentReadDefinition = ToolDefinition(
  name: subagentReadName,
  description:
      "Read a finished subagent's output. Wait to be notified of completion "
      'first. Call again only to continue a paged answer.',
  parameters: <String, Object?>{
    'type': 'object',
    'properties': <String, Object?>{
      'id': <String, Object?>{
        'type': 'string',
        'description': 'The subagent id its completion notice named.',
      },
      'after': <String, Object?>{
        'type': 'string',
        'description': 'Cursor from a previous read. Omit to start at the top.',
      },
      'include': <String, Object?>{
        'type': 'string',
        'enum': <String>['answer', subagentTranscriptView],
        'description':
            "'answer' (default), or 'transcript' for the whole working "
            'history, which is large.',
      },
    },
    'required': <String>['id'],
  },
  onProgress: r'Reading subagent ${id}',
  onSuccess: r'Checked subagent ${id}',
  onError: r'Could not read subagent ${id}',
);

/// The tools an agent uses to run subagents — withheld from subagents
/// themselves, which do not nest.
final ToolDefinitions subagentControlDefinitions = ToolDefinitions([
  subagentDefinition,
  subagentReadDefinition,
]);
