import 'dart:convert';

import 'package:inference/inference.dart';
import 'package:llm_model_templates/llm_model_templates.dart';
import 'package:local_inference_protocol/local_inference_protocol.dart';
import 'package:tool_protocol/tool_protocol.dart';

/// An OpenAI chat-completion request, read from its JSON body.
final class ChatRequest {
  const ChatRequest({
    required this.messages,
    required this.tools,
    required this.stream,
    required this.includeUsage,
    this.stopSequences = const [],
    this.model,
    this.maxTokens,
    this.temperature,
    this.topP,
    this.seed,
    this.frequencyPenalty,
    this.presencePenalty,
    this.reasoningEffort,
    this.enableThinking,
  });

  final String? model;
  final List<PromptMessage> messages;
  final List<PromptTool> tools;
  final bool stream;
  final bool includeUsage;

  /// Text that ends the completion when generated; it is left out of the
  /// reply.
  final List<String> stopSequences;
  final int? maxTokens;
  final double? temperature;
  final double? topP;
  final int? seed;
  final double? frequencyPenalty;
  final double? presencePenalty;
  final String? reasoningEffort;
  final bool? enableThinking;

  /// The request's sampling fields over the model's defaults.
  EngineSampling samplingOver(ModelSamplingDefaults defaults) => EngineSampling(
    seed: seed,
    temperature: temperature ?? defaults.temperature,
    topK: defaults.topK,
    topP: topP ?? defaults.topP,
    minP: defaults.minP,
    penaltyFreq: frequencyPenalty,
    penaltyPresent: presencePenalty,
  );

  /// The mode the model's formatter renders. `reasoning_effort` wins over
  /// `enable_thinking`, and either wins over the model's default.
  String reasoningModeFor(ModelReasoning reasoning) {
    final declined =
        reasoningEffort == 'none' ||
        (reasoningEffort == null && enableThinking == false);
    return switch (reasoning) {
      ModelReasoningNone() => 'off',
      ModelReasoningAlways() => 'on',
      ModelReasoningToggle() => declined ? 'off' : 'on',
      ModelReasoningEfforts(:final efforts) when declined => efforts.first,
      ModelReasoningEfforts(:final efforts)
          when efforts.contains(reasoningEffort) =>
        reasoningEffort!,
      ModelReasoningEfforts(:final efforts) =>
        efforts.contains('medium') ? 'medium' : efforts.first,
    };
  }
}

sealed class ChatRequestParse {
  const ChatRequestParse();
}

final class ChatRequestParsed extends ChatRequestParse {
  const ChatRequestParsed(this.request);

  final ChatRequest request;
}

final class ChatRequestInvalid extends ChatRequestParse {
  const ChatRequestInvalid(this.message);

  final String message;
}

/// The most stop sequences a request may ask for, as OpenAI allows.
const maxStopSequences = 4;

/// Reads chat-completion request bodies.
abstract final class ChatRequestParser {
  static ChatRequestParse parse(String body) {
    try {
      return ChatRequestParsed(_request(_Fields(jsonDecode(body), 'request')));
    } on FormatException catch (error) {
      return ChatRequestInvalid('The body is not JSON: ${error.message}');
    } on _InvalidField catch (error) {
      return ChatRequestInvalid(error.message);
    }
  }

  static ChatRequest _request(_Fields body) {
    final messages = body.list('messages');
    if (messages.isEmpty) throw const _InvalidField('messages is empty.');
    final templateSwitches = body.optionalFields(bestieChatTemplateKwargsField);
    final streamOptions = body.optionalFields('stream_options');
    return ChatRequest(
      model: body.optional<String>('model'),
      messages: _messages(messages),
      tools: [
        for (final tool in body.optionalList('tools'))
          _tool(tool.fields('function')),
      ],
      stream: body.optional<bool>('stream') ?? false,
      includeUsage: streamOptions?.optional<bool>('include_usage') ?? false,
      stopSequences: _stops(body),
      maxTokens: _maxTokens(body),
      temperature: body.optional<num>('temperature')?.toDouble(),
      topP: body.optional<num>('top_p')?.toDouble(),
      seed: body.optional<int>('seed'),
      frequencyPenalty: body.optional<num>('frequency_penalty')?.toDouble(),
      presencePenalty: body.optional<num>('presence_penalty')?.toDouble(),
      reasoningEffort: body.optional<String>('reasoning_effort'),
      enableThinking: templateSwitches?.optional<bool>(
        bestieEnableThinkingKey,
      ),
    );
  }

  static int? _maxTokens(_Fields body) {
    final field = body.raw('max_completion_tokens') == null
        ? 'max_tokens'
        : 'max_completion_tokens';
    final maxTokens = body.optional<int>(field);
    if (maxTokens != null && maxTokens < 1) {
      throw _InvalidField('${body.path}.$field must be at least 1.');
    }
    return maxTokens;
  }

  static List<String> _stops(_Fields body) => switch (body.raw('stop')) {
    null => const [],
    final String stop => [stop],
    final List<Object?> stops
        when stops.length <= maxStopSequences &&
            stops.every((stop) => stop is String) =>
      stops.cast<String>(),
    _ => throw _InvalidField(
      '${body.path}.stop must be a string or a list of at most '
      '$maxStopSequences strings.',
    ),
  };

  static List<PromptMessage> _messages(List<_Fields> messages) {
    final toolNames = <String, String>{};
    return [
      for (final message in messages) _message(message, toolNames),
    ];
  }

  static PromptMessage _message(
    _Fields message,
    Map<String, String> toolNames,
  ) {
    final role = message.required<String>('role');
    return switch (role) {
      'system' => PromptSystemMessage(_content(message)),
      'developer' => PromptDeveloperMessage(_content(message)),
      'user' => PromptUserMessage(_content(message)),
      'assistant' => _assistant(message, toolNames),
      'tool' => _toolResult(message, toolNames),
      _ => throw _InvalidField('${message.path}.role $role is not supported.'),
    };
  }

  static PromptAssistantMessage _assistant(
    _Fields message,
    Map<String, String> toolNames,
  ) {
    final calls = [
      for (final call in message.optionalList('tool_calls')) _toolCall(call),
    ];
    for (final call in calls) {
      toolNames[call.id] = call.name;
    }
    return PromptAssistantMessage(
      content: _content(message),
      reasoning: message.optional<String>('reasoning_content'),
      toolCalls: calls,
    );
  }

  static ToolCall _toolCall(_Fields call) {
    final function = call.fields('function');
    final arguments = function.optional<String>('arguments') ?? '{}';
    return ToolCallDefault(
      id: call.required<String>('id'),
      name: function.required<String>('name'),
      arguments: _argumentsOf(arguments),
    );
  }

  /// A model that wrote arguments that are not a JSON object sees them as
  /// empty when its turn is replayed.
  static Map<String, Object?> _argumentsOf(String arguments) {
    try {
      final decoded = jsonDecode(arguments);
      return decoded is Map<String, Object?> ? decoded : const {};
    } on FormatException {
      return const {};
    }
  }

  static PromptToolMessage _toolResult(
    _Fields message,
    Map<String, String> toolNames,
  ) {
    final callId = message.required<String>('tool_call_id');
    return PromptToolMessage(
      toolCallId: callId,
      name: message.optional<String>('name') ?? toolNames[callId] ?? '',
      content: _content(message),
    );
  }

  static String _content(_Fields message) {
    final content = message.raw('content');
    return switch (content) {
      null => '',
      final String text => text,
      final List<Object?> parts => [
        for (final part in parts)
          if (part case {'type': 'text', 'text': final String text}) text,
      ].join(),
      _ => throw _InvalidField(
        '${message.path}.content must be a string or a list of parts.',
      ),
    };
  }

  static PromptTool _tool(_Fields function) => PromptTool(
    name: function.required<String>('name'),
    description: function.optional<String>('description') ?? '',
    parameters: function.optionalFields('parameters')?.values ?? const {},
  );
}

/// A JSON object read field by field, naming the field that broke when one
/// has the wrong shape.
final class _Fields {
  _Fields(Object? json, this.path)
    : values = json is Map<String, Object?>
          ? json
          : throw _InvalidField('$path must be an object.');

  final Map<String, Object?> values;
  final String path;

  Object? raw(String key) => values[key];

  T? optional<T>(String key) => switch (values[key]) {
    null => null,
    final T value => value,
    _ => throw _InvalidField('$path.$key has the wrong type.'),
  };

  T required<T>(String key) =>
      optional<T>(key) ?? (throw _InvalidField('$path.$key is required.'));

  _Fields fields(String key) => _Fields(values[key], '$path.$key');

  _Fields? optionalFields(String key) =>
      values[key] == null ? null : fields(key);

  List<_Fields> list(String key) {
    final items = required<List<Object?>>(key);
    return [
      for (var index = 0; index < items.length; index++)
        _Fields(items[index], '$path.$key[$index]'),
    ];
  }

  List<_Fields> optionalList(String key) =>
      values[key] == null ? const [] : list(key);
}

final class _InvalidField implements Exception {
  const _InvalidField(this.message);

  final String message;
}
