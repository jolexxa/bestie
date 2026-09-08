import 'package:bestie_tools_use_case/src/definitions/utility_tool_names.dart';
import 'package:tool_protocol/tool_protocol.dart';

const calculatorDefinition = ToolDefinition(
  name: UtilityToolNames.calculator,
  onProgress: r'Calculating ${expression}',
  onSuccess: r'Calculated ${expression}',
  onError: r'Failed to evaluate ${expression}',
  description:
      'Evaluates a mathematical expression and returns the result. '
      'Supports: +, -, *, /, %, ^ (power), comparisons, boolean logic, '
      'and functions like SQRT, SIN, COS, LOG, ROUND, MIN, MAX, ABS, IF.',
  parameters: <String, Object?>{
    'type': 'object',
    'properties': <String, Object?>{
      'expression': <String, Object?>{
        'type': 'string',
        'description':
            'The mathematical expression to evaluate. '
            'Examples: "2 ^ 10", "SQRT(144)", "IF(3 > 2, 1, 0)".',
      },
    },
    'required': <String>['expression'],
  },
);

const dateTimeDefinition = ToolDefinition(
  name: UtilityToolNames.dateTime,
  onProgress: 'Checking the time',
  onSuccess: 'Checked the time',
  onError: 'Failed to get the time',
  description:
      'Returns the current local (not UTC) date/time in ISO 8601 format.',
  parameters: <String, Object?>{
    'type': 'object',
    'properties': <String, Object?>{},
    'required': <String>[],
  },
);
