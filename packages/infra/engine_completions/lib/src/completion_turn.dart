import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:engine_completions/src/agent_sequence_session.dart';
import 'package:engine_completions/src/models/completion_models.dart';
import 'package:engine_completions/src/stop_matcher.dart';
import 'package:engine_protocol/engine_protocol.dart';
import 'package:engine_scheduler/engine_scheduler.dart';
import 'package:engine_templates/engine_templates.dart';
import 'package:tool_protocol/tool_protocol.dart';

enum EngineCompletionTurnPhase { materializing, decoding, settled }

/// One completion running on a session's sequence: first its prompt is
/// materialized, then one token is sampled per scheduler step until the model
/// stops.
final class EngineCompletionTurn {
  EngineCompletionTurn({
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
    _events.onCancel = () => phase = EngineCompletionTurnPhase.settled;
  }

  final AgentSequenceSession session;
  final TokenizedString prompt;
  final StreamParserSession _parser;
  final Detokenizer _detokenizer;
  final CallIdMinter _callIdMinter;
  final StopMatcher _stops;
  final int? _maxTokens;
  final _events = StreamController<EngineCompletionEvent>();
  final _utf8 = Utf8StreamDecoder();
  final _generated = <TokenId>[];
  final Stopwatch _stopwatch = clock.stopwatch()..start();
  var _cachedTokens = 0;
  Duration _promptTime = Duration.zero;
  var _unreportedTokens = 0;
  var _calledTools = false;

  EngineCompletionTurnPhase phase = EngineCompletionTurnPhase.materializing;

  Stream<EngineCompletionEvent> get events => _events.stream;

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
        if (_generated.isEmpty) _prefilled(materialization);
        phase = EngineCompletionTurnPhase.decoding;
      case SequenceMaterializeAdvanced(:final materialization):
        if (_generated.isEmpty) _reportPrefill(materialization);
      case SequenceMaterializeDeferred(:final reason):
        _deferMaterialize(reason);
      case SequenceMaterializeFailed(:final reason):
        fail(EngineCompletionFailure.engineFailed, reason.name);
    }
  }

  void _prefilled(SequenceMaterialization materialization) {
    _cachedTokens = materialization.reusedTokenCount;
    _promptTime = _stopwatch.elapsed;
    _reportPrefill(materialization);
  }

  void _reportPrefill(SequenceMaterialization materialization) => _events.add(
    EngineCompletionPrefillProgressed(
      total: materialization.tokens.length,
      cached: materialization.reusedTokenCount,
      processed: materialization.materializedTokenCount,
      elapsed: _stopwatch.elapsed,
    ),
  );

  void _deferMaterialize(SequenceSchedulerDeferralReason reason) {
    switch (reason) {
      case SequenceSchedulerDeferralReason.effectiveLimitReached ||
          SequenceSchedulerDeferralReason.requestWouldExceedEffectiveLimit:
        fail(EngineCompletionFailure.contextExceeded, reason.name);
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
        _finish(EngineCompletionStopReason.stop);
      case SequenceSampleDeferred(:final reason):
        _deferSample(reason);
      case SequenceSampleFailed(:final reason):
        fail(EngineCompletionFailure.engineFailed, reason.name);
    }
  }

  void _deferSample(SequenceSchedulerDeferralReason reason) {
    switch (reason) {
      case SequenceSchedulerDeferralReason.effectiveLimitReached ||
          SequenceSchedulerDeferralReason.requestWouldExceedEffectiveLimit:
        _finish(EngineCompletionStopReason.length);
      case SequenceSchedulerDeferralReason.logitsUnavailable:
        phase = EngineCompletionTurnPhase.materializing;
      case SequenceSchedulerDeferralReason.batchCapacityExhausted ||
          SequenceSchedulerDeferralReason.backendBackpressure:
        break;
    }
  }

  void _acceptToken(TokenId token) {
    _generated.add(token);
    _unreportedTokens++;
    switch (_detokenizer.detokenize(DetokenizeRequest(token: token))) {
      case DetokenizeSucceeded(:final bytes):
        _scan(_utf8.add(bytes));
      case DetokenizeFailed(:final message):
        fail(EngineCompletionFailure.engineFailed, message);
    }
  }

  void _scan(String text) {
    switch (_stops.add(text)) {
      case StopMatched(:final released):
        _parse(released, tokenCount: 1);
        _utf8.flush();
        _finish(EngineCompletionStopReason.stop);
      case StopUnmatched(:final released):
        _parse(released, tokenCount: 1);
        if (_generated.length == _maxTokens) {
          _finish(EngineCompletionStopReason.length);
        }
    }
  }

  void _finish(EngineCompletionStopReason reason) {
    _parse('${_utf8.flush()}${_stops.flush()}', tokenCount: 0);
    _emitAll(_parser.finish());
    _settle(
      EngineCompletionFinished(
        reason: _calledTools && reason == EngineCompletionStopReason.stop
            ? EngineCompletionStopReason.toolCalls
            : reason,
        usage: EngineCompletionUsage(
          promptTokens: prompt.length,
          completionTokens: _generated.length,
          cachedTokens: _cachedTokens,
          promptTime: _promptTime,
          generationTime: _stopwatch.elapsed - _promptTime,
        ),
      ),
    );
  }

  /// Ends the completion early with [failure].
  void fail(EngineCompletionFailure failure, String message) {
    _settle(EngineCompletionFailed(failure: failure, message: message));
  }

  void _settle(EngineCompletionEvent last) {
    if (phase == EngineCompletionTurnPhase.settled) return;
    phase = EngineCompletionTurnPhase.settled;
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
          _events.add(EngineCompletionTextDelta(text, tokens: _takeTokens()));
        case ModelReasoningDelta(:final text) when text.isNotEmpty:
          _events.add(
            EngineCompletionReasoningDelta(text, tokens: _takeTokens()),
          );
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
      EngineCompletionToolCalled(
        id: 'call_${_callIdMinter.mint()}',
        name: name,
        argumentsJson: argumentsJson,
        tokens: _takeTokens(),
      ),
    );
  }

  /// The tokens generated since the last event that carried any.
  int _takeTokens() {
    final tokens = _unreportedTokens;
    _unreportedTokens = 0;
    return tokens;
  }
}
