import 'dart:typed_data';

import 'package:inference/inference.dart';
import 'package:inference_llama/src/context/llama_context_results.dart';
import 'package:inference_llama/src/native/llama_client.dart';
import 'package:inference_llama/src/native/llama_sampler_chain.dart';
import 'package:inference_llama/src/native/models/models.dart';
import 'package:isolate_worker/isolate_worker.dart';

final class LlamaContextEngine {
  LlamaContextEngine({
    required LlamaClientApi client,
    required LlamaModelHandle model,
    required LlamaContextHandle context,
    required this.envelope,
  }) : _client = client,
       _model = model,
       _context = context;

  final LlamaClientApi _client;
  final LlamaModelHandle _model;
  final LlamaContextHandle _context;
  final Map<SequenceId, _SequenceState> _sequences = {};
  var _logitsGeneration = 0;
  var _disposed = false;

  final ContextEnvelope envelope;

  int get maxSequences => envelope.maxSequences;

  int get maxBatchTokens => envelope.maxBatchTokens;

  AcquireLlamaSequenceResponse acquire(SequenceRequest request) {
    if (_disposed) {
      return _acquireFailedMessage('LlamaContext is disposed.');
    }
    final id = _firstAvailableSequenceId();
    if (id == null) {
      return _acquireFailedMessage('No sequence slots are available.');
    }

    _createSequence(
      id,
      _buildSampler(request.sampling),
    );
    return AcquireLlamaSequenceSucceeded(id);
  }

  ReleaseLlamaSequenceResponse release(SequenceId id) {
    if (_disposed) {
      return _releaseFailedMessage('LlamaContext is disposed.');
    }
    final state = _sequences.remove(id);
    if (state == null) {
      return _releaseFailedMessage('Sequence $id has not been acquired.');
    }

    // Free the sequence's KV cells so a reused slot can never inherit them.
    _freeCells(id);
    state.dispose();
    return const ReleaseLlamaSequenceSucceeded();
  }

  ClearLlamaSequenceResponse clear(SequenceId id) {
    if (_disposed) {
      return _clearFailedMessage('LlamaContext is disposed.');
    }
    final state = _sequences[id];
    if (state == null) {
      return _clearFailedMessage('Sequence $id has not been acquired.');
    }

    if (!_freeCells(id)) {
      return _clearFailedMessage('Failed to clear sequence $id.');
    }
    state
      ..resetSamplerHistory()
      ..invalidateTicket();
    return const ClearLlamaSequenceSucceeded();
  }

  bool _freeCells(SequenceId id) {
    // Some memory backends report a resident position range that is narrower
    // than the full sequence footprint, so clear/release must remove all cells.
    return _client.removeSequenceRange(_context, id, -1, -1);
  }

  SetLlamaSamplingResponse setSampling(
    SequenceId id,
    EngineSampling sampling,
  ) {
    if (_disposed) {
      return _samplingFailedMessage('LlamaContext is disposed.');
    }
    final state = _sequences[id];
    if (state == null) {
      return _samplingFailedMessage('Sequence $id has not been acquired.');
    }

    state
      ..resetSampler(_buildSampler(sampling))
      ..invalidateTicket();
    return const SetLlamaSamplingSucceeded();
  }

  RemoveLlamaSequenceRangeResponse removeRange(
    SequenceId id, {
    required int start,
    required int end,
  }) {
    if (_disposed) {
      return _removeFailedMessage('LlamaContext is disposed.');
    }
    if (!_sequences.containsKey(id)) {
      return _removeFailedMessage('Sequence $id has not been acquired.');
    }
    final removed = _client.removeSequenceRange(_context, id, start, end);
    if (!removed) {
      return _removeFailedMessage(
        'Failed to remove range [$start, $end) from sequence $id.',
      );
    }
    _sequences[id]!.invalidateTicket();
    return const RemoveLlamaSequenceRangeSucceeded();
  }

  RebuildLlamaSamplerResponse rebuildSampler(
    SequenceId id,
    TokenizedString acceptedTokens,
  ) {
    if (_disposed) {
      return _rebuildSamplerFailedMessage('LlamaContext is disposed.');
    }
    final state = _sequences[id];
    if (state == null) {
      return _rebuildSamplerFailedMessage(
        'Sequence $id has not been acquired.',
      );
    }
    state
      ..resetSamplerHistory()
      ..invalidateTicket();
    for (final token in acceptedTokens) {
      _client.acceptToken(state.sampler, token);
    }
    return const RebuildLlamaSamplerSucceeded();
  }

  ReadLlamaKvSnapshotResponse kvSnapshot() {
    if (_disposed) {
      return _snapshotFailedMessage('LlamaContext is disposed.');
    }
    return ReadLlamaKvSnapshotSucceeded(
      KvSnapshot(
        contextSize: envelope.contextSize,
        sequences: [
          for (final id in _sequences.keys)
            SequenceKvState(
              sequenceId: id,
              positionMin: _client.sequencePositionMin(_context, id),
              positionMax: _client.sequencePositionMax(_context, id),
            ),
        ],
      ),
    );
  }

  ReadLlamaSequenceCheckpointResponse readCheckpoint(SequenceId id) {
    if (_disposed) {
      return _readCheckpointFailedMessage('LlamaContext is disposed.');
    }
    if (!_sequences.containsKey(id)) {
      return _readCheckpointFailedMessage(
        'Sequence $id has not been acquired.',
      );
    }
    return ReadLlamaSequenceCheckpointSucceeded(
      _client.readSequenceCheckpoint(_context, id, full: envelope.isRecurrent),
    );
  }

  RestoreLlamaSequenceCheckpointResponse restoreCheckpoint(
    SequenceId id,
    Uint8List bytes,
  ) {
    if (_disposed) {
      return _restoreCheckpointFailedMessage('LlamaContext is disposed.');
    }
    final state = _sequences[id];
    if (state == null) {
      return _restoreCheckpointFailedMessage(
        'Sequence $id has not been acquired.',
      );
    }
    final restored = _client.writeSequenceCheckpoint(
      _context,
      id,
      bytes,
      full: envelope.isRecurrent,
    );
    if (!restored) {
      return _restoreCheckpointFailedMessage(
        'Failed to restore checkpoint into sequence $id.',
      );
    }
    state.invalidateTicket();
    return const RestoreLlamaSequenceCheckpointSucceeded();
  }

  StepLlamaBatchResponse stepBatch(
    StepRequest request, {
    IsolateCancellationToken cancellationToken =
        const NeverCancelledIsolateCancellationToken(),
  }) {
    if (_disposed) {
      return _stepFailedMessage('LlamaContext is disposed.');
    }

    final seenSequenceIds = <SequenceId>{};
    final ticketKeys = <String>{};
    final activeTickets = <_ActiveLogitsTicket>[];
    for (final sample in request.samples) {
      final ticket = sample.logitsTicket;
      final key =
          '${ticket.sequenceId}:${ticket.generation}:${ticket.batchIndex}';
      if (!ticketKeys.add(key)) {
        return _stepFailedMessage(
          'Logits ticket for sequence ${ticket.sequenceId} was reused.',
        );
      }
      if (!seenSequenceIds.add(ticket.sequenceId)) {
        return _stepFailedMessage(
          'Sequence ${ticket.sequenceId} appears more than once in the step.',
        );
      }
      switch (_validateTicket(ticket)) {
        case final _ActiveLogitsTicket active:
          activeTickets.add(active);
        case _InvalidLogitsTicket(:final message):
          return _stepFailedMessage(message);
      }
    }

    final prefillPositions = <SequenceId, _PositionRange>{};
    for (final prefill in request.prefills) {
      if (!seenSequenceIds.add(prefill.sequenceId)) {
        return _stepFailedMessage(
          'Sequence ${prefill.sequenceId} appears more than once in the step.',
        );
      }
      if (!_sequences.containsKey(prefill.sequenceId)) {
        return _stepFailedMessage(
          'Sequence ${prefill.sequenceId} has not been acquired.',
        );
      }
      if (prefill.tokens.isEmpty) {
        return _stepFailedMessage(
          'Sequence ${prefill.sequenceId} has no tokens to append.',
        );
      }
      final start =
          _client.sequencePositionMax(_context, prefill.sequenceId) + 1;
      prefillPositions[prefill.sequenceId] = _PositionRange(
        min: start,
        max: start + prefill.tokens.length - 1,
      );
    }

    if (cancellationToken.isCancellationRequested) {
      return _stepCancelledBeforeMutation();
    }

    final selections = <_StepSelection>[];
    for (final active in activeTickets) {
      final sampler = active.state.sampler.clone();
      final token = _client.sampleAt(
        _context,
        sampler,
        active.ticket.batchIndex,
      );
      selections.add(
        _StepSelection(
          state: active.state,
          sampler: sampler,
          sequenceId: active.ticket.sequenceId,
          token: token,
          position: active.ticket.position + 1,
          isEndOfGeneration: _client.isEndOfGeneration(_model, token),
        ),
      );
    }

    final entries = <BatchEntry>[
      for (final selection in selections)
        if (!selection.isEndOfGeneration)
          BatchEntry(
            token: selection.token,
            pos: selection.position,
            seqId: selection.sequenceId,
            logits: true,
          ),
      ..._interleavedEntries(request.prefills, prefillPositions),
    ];
    if (entries.length > envelope.maxBatchTokens) {
      for (final selection in selections) {
        selection.sampler.dispose();
      }
      return _stepFailedMessage(
        'Step batch size ${entries.length} exceeds '
        'nBatch ${envelope.maxBatchTokens}.',
      );
    }

    final decodeFailure = _dispatch(entries);
    if (decodeFailure != null) {
      for (final selection in selections) {
        selection.sampler.dispose();
        if (decodeFailure.backendCode != decodeKvSlotUnavailableBackendCode) {
          selection.state.invalidateTicket();
        }
      }
      return _stepFailed(decodeFailure, diagnostics: _kvDiagnostics(entries));
    }

    final ticketBySequenceId = <SequenceId, LogitsTicket>{};
    for (var batchIndex = 0; batchIndex < entries.length; batchIndex++) {
      final entry = entries[batchIndex];
      if (!entry.logits) continue;
      final ticket = LogitsTicket(
        sequenceId: entry.seqId,
        position: entry.pos,
        batchIndex: batchIndex,
        generation: _logitsGeneration,
      );
      _sequences[entry.seqId]!.setTicket(ticket);
      ticketBySequenceId[entry.seqId] = ticket;
    }

    final sampleResults = <SampleSequenceResult>[];
    for (final selection in selections) {
      _client.acceptToken(selection.sampler, selection.token);
      selection.state.resetSampler(selection.sampler);
      if (selection.isEndOfGeneration) {
        selection.state.invalidateTicket();
        sampleResults.add(
          SampleSequenceStopped(
            sequenceId: selection.sequenceId,
            token: selection.token,
          ),
        );
        continue;
      }
      sampleResults.add(
        SampleSequenceToken(
          sequenceId: selection.sequenceId,
          token: selection.token,
          position: selection.position,
          nextLogitsTicket: ticketBySequenceId[selection.sequenceId]!,
        ),
      );
    }

    final prefillResults = <PrefillSequenceResult>[];
    for (final prefill in request.prefills) {
      final state = _sequences[prefill.sequenceId]!;
      if (prefill.samplerMode == PrefillSamplerMode.accept) {
        for (final token in prefill.tokens) {
          _client.acceptToken(state.sampler, token);
        }
      }
      prefillResults.add(
        _prefillResult(
          prefill,
          prefillPositions[prefill.sequenceId]!,
          ticketBySequenceId[prefill.sequenceId],
        ),
      );
    }

    return StepLlamaBatchSucceeded(
      samples: sampleResults,
      prefills: prefillResults,
    );
  }

  void dispose() {
    if (_disposed) return;

    _disposed = true;
    for (final state in _sequences.values) {
      state.dispose();
    }
    _sequences.clear();
    _client.disposeContext(_context);
  }

  SequenceId? _firstAvailableSequenceId() {
    for (var id = 0; id < maxSequences; id++) {
      if (!_sequences.containsKey(id)) {
        return id;
      }
    }
    return null;
  }

  void _createSequence(
    SequenceId id,
    LlamaSamplerChain sampler,
  ) {
    _sequences[id] = _SequenceState(
      sampler: sampler,
    );
  }

  LlamaSamplerChain _buildSampler(EngineSampling sampling) {
    return _client.createSampler(_model, sampling);
  }

  PrefillSequenceResult _prefillResult(
    PrefillRequest request,
    _PositionRange position,
    LogitsTicket? ticket,
  ) {
    if (ticket != null) {
      return PrefillSequenceWithLogitsSucceeded(
        sequenceId: request.sequenceId,
        positionMin: position.min,
        positionMax: position.max,
        logitsTicket: ticket,
      );
    }
    return PrefillSequenceSucceeded(
      sequenceId: request.sequenceId,
      positionMin: position.min,
      positionMax: position.max,
    );
  }

  _TicketValidationResult _validateTicket(LogitsTicket ticket) {
    final state = _sequences[ticket.sequenceId];
    if (state == null) {
      return _InvalidLogitsTicket(
        'Sequence ${ticket.sequenceId} has not been acquired.',
      );
    }
    if (ticket.generation != _logitsGeneration) {
      return _InvalidLogitsTicket(
        'Logits ticket for sequence ${ticket.sequenceId} is stale.',
      );
    }
    final active = state.ticket;
    if (active == null) {
      return _InvalidLogitsTicket(
        'Sequence ${ticket.sequenceId} has no active logits ticket.',
      );
    }
    if (active.ticket.position != ticket.position ||
        active.ticket.batchIndex != ticket.batchIndex ||
        active.ticket.generation != ticket.generation) {
      return _InvalidLogitsTicket(
        'Logits ticket for sequence ${ticket.sequenceId} is not current.',
      );
    }
    return _ActiveLogitsTicket(state: state, ticket: ticket);
  }

  _DecodeFailure? _dispatch(List<BatchEntry> entries) {
    if (entries.isEmpty) return null;
    final result = _client.decodeBatch(_context, entries);
    return switch (result) {
      LlamaDecodeSucceeded() => _decodeSucceeded(),
      LlamaDecodeFailed(
        :final message,
        :final stackTrace,
        :final backendCode,
      ) =>
        _DecodeFailure(
          message: message,
          stackTrace: stackTrace,
          backendCode: backendCode,
        ),
    };
  }

  _DecodeFailure? _decodeSucceeded() {
    _logitsGeneration++;
    return null;
  }

  /// Physical KV occupancy at the moment a decode failed, so a `code 1`
  /// ("could not find a KV slot") can be read against what the cache actually
  /// holds rather than what the caller tracked logically.
  String _kvDiagnostics(List<BatchEntry> entries) {
    final batchBySeq = <SequenceId, int>{};
    for (final entry in entries) {
      batchBySeq[entry.seqId] = (batchBySeq[entry.seqId] ?? 0) + 1;
    }
    var occupied = 0;
    final lines = <String>[];
    for (final id in _sequences.keys) {
      final min = _client.sequencePositionMin(_context, id);
      final max = _client.sequencePositionMax(_context, id);
      final cells = (min >= 0 && max >= min) ? max - min + 1 : 0;
      occupied += cells;
      final batch = batchBySeq[id] ?? 0;
      lines.add('seq $id: cells=$cells [$min,$max] +$batch');
    }
    final free = envelope.contextSize - occupied;
    return 'kv occupied=$occupied/${envelope.contextSize} free=$free '
        'batch=${entries.length} | ${lines.join(' · ')}';
  }
}

List<BatchEntry> _interleavedEntries(
  List<PrefillRequest> requests,
  Map<SequenceId, _PositionRange> positions,
) {
  var maxLength = 0;
  for (final request in requests) {
    if (request.tokens.length > maxLength) {
      maxLength = request.tokens.length;
    }
  }

  final entries = <BatchEntry>[];
  for (var offset = 0; offset < maxLength; offset++) {
    for (final request in requests) {
      if (offset >= request.tokens.length) continue;
      entries.add(
        BatchEntry(
          token: request.tokens[offset],
          pos: positions[request.sequenceId]!.min + offset,
          seqId: request.sequenceId,
          logits: request.retainLogits && offset == request.tokens.length - 1,
        ),
      );
    }
  }
  return entries;
}

final class _SequenceState {
  _SequenceState({
    required this.sampler,
  });

  LlamaSamplerChain sampler;
  _TicketState? ticket;

  void resetSampler(LlamaSamplerChain next) {
    sampler.dispose();
    sampler = next;
  }

  void resetSamplerHistory() {
    sampler.reset();
  }

  void setTicket(LogitsTicket next) {
    ticket = _TicketState(next);
  }

  void invalidateTicket() {
    ticket = null;
  }

  void dispose() {
    sampler.dispose();
    invalidateTicket();
  }
}

final class _TicketState {
  _TicketState(this.ticket);

  final LogitsTicket ticket;
}

sealed class _TicketValidationResult {
  const _TicketValidationResult();
}

final class _ActiveLogitsTicket extends _TicketValidationResult {
  const _ActiveLogitsTicket({
    required this.state,
    required this.ticket,
  });

  final _SequenceState state;
  final LogitsTicket ticket;
}

final class _StepSelection {
  const _StepSelection({
    required this.state,
    required this.sampler,
    required this.sequenceId,
    required this.token,
    required this.position,
    required this.isEndOfGeneration,
  });

  final _SequenceState state;
  final LlamaSamplerChain sampler;
  final SequenceId sequenceId;
  final TokenId token;
  final int position;
  final bool isEndOfGeneration;
}

final class _InvalidLogitsTicket extends _TicketValidationResult {
  const _InvalidLogitsTicket(this.message);

  final String message;
}

final class _DecodeFailure {
  const _DecodeFailure({
    required this.message,
    required this.stackTrace,
    required this.backendCode,
  });

  final String message;
  final String stackTrace;
  final int backendCode;
}

AcquireLlamaSequenceFailed _acquireFailedMessage(
  String message, [
  String stackTrace = '',
]) {
  return AcquireLlamaSequenceFailed(message: message, stackTrace: stackTrace);
}

ReleaseLlamaSequenceFailed _releaseFailedMessage(
  String message, [
  String stackTrace = '',
]) {
  return ReleaseLlamaSequenceFailed(message: message, stackTrace: stackTrace);
}

ClearLlamaSequenceFailed _clearFailedMessage(
  String message, [
  String stackTrace = '',
]) {
  return ClearLlamaSequenceFailed(message: message, stackTrace: stackTrace);
}

SetLlamaSamplingFailed _samplingFailedMessage(
  String message, [
  String stackTrace = '',
]) {
  return SetLlamaSamplingFailed(message: message, stackTrace: stackTrace);
}

RemoveLlamaSequenceRangeFailed _removeFailedMessage(
  String message, [
  String stackTrace = '',
]) {
  return RemoveLlamaSequenceRangeFailed(
    message: message,
    stackTrace: stackTrace,
  );
}

RebuildLlamaSamplerFailed _rebuildSamplerFailedMessage(
  String message, [
  String stackTrace = '',
]) {
  return RebuildLlamaSamplerFailed(message: message, stackTrace: stackTrace);
}

ReadLlamaKvSnapshotFailed _snapshotFailedMessage(
  String message, [
  String stackTrace = '',
]) {
  return ReadLlamaKvSnapshotFailed(message: message, stackTrace: stackTrace);
}

ReadLlamaSequenceCheckpointFailed _readCheckpointFailedMessage(
  String message, [
  String stackTrace = '',
]) {
  return ReadLlamaSequenceCheckpointFailed(
    message: message,
    stackTrace: stackTrace,
  );
}

RestoreLlamaSequenceCheckpointFailed _restoreCheckpointFailedMessage(
  String message, [
  String stackTrace = '',
]) {
  return RestoreLlamaSequenceCheckpointFailed(
    message: message,
    stackTrace: stackTrace,
  );
}

StepLlamaBatchFailed _stepFailed(
  _DecodeFailure failure, {
  required String diagnostics,
}) {
  return _stepFailedMessage(
    '${failure.message} ($diagnostics)',
    stackTrace: failure.stackTrace,
    backendCode: failure.backendCode,
  );
}

StepLlamaBatchFailed _stepCancelledBeforeMutation() {
  return _stepFailedMessage('Step cancelled before mutation.');
}

StepLlamaBatchFailed _stepFailedMessage(
  String message, {
  String stackTrace = '',
  int? backendCode,
}) {
  return StepLlamaBatchFailed(
    message: message,
    stackTrace: stackTrace,
    backendCode: backendCode,
  );
}

final class _PositionRange {
  const _PositionRange({required this.min, required this.max});

  final int min;
  final int max;
}
