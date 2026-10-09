import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:completion_runtime/src/agent_sequence_session.dart';
import 'package:completion_runtime/src/models/completion_models.dart';
import 'package:completion_runtime/src/stop_matcher.dart';
import 'package:inference/inference.dart';
import 'package:inference_runtime/inference_runtime.dart';
import 'package:llm_model_templates/llm_model_templates.dart';
import 'package:tool_protocol/tool_protocol.dart';

enum CompletionTurnPhase { materializing, decoding, settled }

/// One completion running on a session's sequence: first its prompt is
/// materialized, then one token is sampled per scheduler step until the model
/// stops.
final class CompletionTurn {
  CompletionTurn({
    required this.session,
    required this.prompt,
    required StreamParserSession parser,
    required Detokenizer detokenizer,
    required CallIdMinter callIdMinter,
    required StopMatcher stops,
    required int? maxTokens,
  }) : _parser = parser,
       _detokenizer = detokenizer,
       _callIdMinter = callIdMinter,
       _stops = stops,
       _maxTokens = maxTokens {
    _events.onCancel = () => phase = CompletionTurnPhase.settled;
  }

  final AgentSequenceSession session;
  final TokenizedString prompt;
  final StreamParserSession _parser;
  final Detokenizer _detokenizer;
  final CallIdMinter _callIdMinter;
  final StopMatcher _stops;
  final int? _maxTokens;
  final _events = StreamController<CompletionEvent>();
  final _utf8 = Utf8StreamDecoder();
  final _generated = <TokenId>[];
  var _cachedTokens = 0;
  var _calledTools = false;

  CompletionTurnPhase phase = CompletionTurnPhase.materializing;

  Stream<CompletionEvent> get events => _events.stream;

  /// The prompt plus every token generated so far, which is what the
  /// sequence must hold for the next sample.
  SequenceMaterializeRequest get materializeRequest =>
      SequenceMaterializeRequest(
        lease: session.lease,
        tokens: _generated.isEmpty
            ? prompt
            : Int64List.fromList([...prompt, ..._generated]),
      );

  SequenceSampleRequest get sampleRequest =>
      SequenceSampleRequest(lease: session.lease);

  void acceptMaterialize(SequenceMaterializeResult result) {
    switch (result) {
      case SequenceMaterializeSucceeded(:final materialization):
        if (_generated.isEmpty) {
          _cachedTokens = materialization.reusedTokenCount;
        }
        phase = CompletionTurnPhase.decoding;
      case SequenceMaterializeAdvanced():
        break;
      case SequenceMaterializeDeferred(:final reason):
        _deferMaterialize(reason);
      case SequenceMaterializeFailed(:final reason):
        fail(CompletionFailure.engineFailed, reason.name);
    }
  }

  void _deferMaterialize(SequenceSchedulerDeferralReason reason) {
    switch (reason) {
      case SequenceSchedulerDeferralReason.effectiveLimitReached ||
          SequenceSchedulerDeferralReason.requestWouldExceedEffectiveLimit:
        fail(CompletionFailure.contextExceeded, reason.name);
      case SequenceSchedulerDeferralReason.logitsUnavailable ||
          SequenceSchedulerDeferralReason.batchCapacityExhausted ||
          SequenceSchedulerDeferralReason.backendBackpressure:
        break;
    }
  }

  void acceptSample(SequenceSampleResult result) {
    switch (result) {
      case SequenceSampleSucceeded(result: SampleSequenceToken(:final token)):
        _acceptToken(token);
      case SequenceSampleSucceeded(result: SampleSequenceStopped()):
        _finish(CompletionStopReason.stop);
      case SequenceSampleDeferred(:final reason):
        _deferSample(reason);
      case SequenceSampleFailed(:final reason):
        fail(CompletionFailure.engineFailed, reason.name);
    }
  }

  void _deferSample(SequenceSchedulerDeferralReason reason) {
    switch (reason) {
      case SequenceSchedulerDeferralReason.effectiveLimitReached ||
          SequenceSchedulerDeferralReason.requestWouldExceedEffectiveLimit:
        _finish(CompletionStopReason.length);
      case SequenceSchedulerDeferralReason.logitsUnavailable:
        phase = CompletionTurnPhase.materializing;
      case SequenceSchedulerDeferralReason.batchCapacityExhausted ||
          SequenceSchedulerDeferralReason.backendBackpressure:
        break;
    }
  }

  void _acceptToken(TokenId token) {
    _generated.add(token);
    switch (_detokenizer.detokenize(DetokenizeRequest(token: token))) {
      case DetokenizeSucceeded(:final bytes):
        _scan(_utf8.add(bytes));
      case DetokenizeFailed(:final message):
        fail(CompletionFailure.engineFailed, message);
    }
  }

  void _scan(String text) {
    switch (_stops.add(text)) {
      case StopMatched(:final released):
        _parse(released, tokenCount: 1);
        _utf8.flush();
        _finish(CompletionStopReason.stop);
      case StopUnmatched(:final released):
        _parse(released, tokenCount: 1);
        if (_generated.length == _maxTokens) {
          _finish(CompletionStopReason.length);
        }
    }
  }

  void _finish(CompletionStopReason reason) {
    _parse('${_utf8.flush()}${_stops.flush()}', tokenCount: 0);
    _emitAll(_parser.finish());
    _settle(
      CompletionFinished(
        reason: _calledTools && reason == CompletionStopReason.stop
            ? CompletionStopReason.toolCalls
            : reason,
        usage: CompletionUsage(
          promptTokens: prompt.length,
          completionTokens: _generated.length,
          cachedTokens: _cachedTokens,
        ),
      ),
    );
  }

  /// Ends the completion early with [failure].
  void fail(CompletionFailure failure, String message) {
    _settle(CompletionFailed(failure: failure, message: message));
  }

  void _settle(CompletionEvent last) {
    if (phase == CompletionTurnPhase.settled) return;
    phase = CompletionTurnPhase.settled;
    _events.add(last);
    unawaited(_events.close());
  }

  void _parse(String text, {required int tokenCount}) => _emitAll(
    _parser.add(StreamChunk(text: text, tokenCountDelta: tokenCount)),
  );

  void _emitAll(Iterable<ModelOutput> outputs) {
    for (final output in outputs) {
      switch (output) {
        case ModelTextDelta(:final text) when text.isNotEmpty:
          _events.add(CompletionTextDelta(text));
        case ModelReasoningDelta(:final text) when text.isNotEmpty:
          _events.add(CompletionReasoningDelta(text));
        case ModelToolCallOutput(:final call):
          _callTool(call.name, jsonEncode(call.arguments));
        case ModelToolCallUnparsed(:final name, :final rawText):
          _callTool(name ?? 'unparsed_tool_call', rawText);
        case ModelTextDelta() ||
            ModelReasoningDelta() ||
            ModelTokensGenerated() ||
            ModelStepFinished():
          break;
      }
    }
  }

  void _callTool(String name, String argumentsJson) {
    _calledTools = true;
    _events.add(
      CompletionToolCalled(
        id: 'call_${_callIdMinter.mint()}',
        name: name,
        argumentsJson: argumentsJson,
      ),
    );
  }
}
