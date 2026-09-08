import 'package:vt_parser/vt_parser.dart';

/// A [ParserSink] that appends every event to a public list so tests
/// can assert on the dispatched sequence without going through a
/// broadcast stream.
class Collector implements ParserSink {
  final List<ParserEvent> events = <ParserEvent>[];

  @override
  void onPrint(int char) => events.add(PrintEvent(char));

  @override
  void onExecute(int byte) => events.add(ExecuteEvent(byte));

  @override
  void onEscDispatch({
    required List<int> intermediates,
    required int finalByte,
    required bool ignore,
  }) {
    events.add(
      EscDispatchEvent(
        intermediates: List<int>.of(intermediates),
        finalByte: finalByte,
        ignore: ignore,
      ),
    );
  }

  @override
  void onCsiDispatch({
    required List<List<int>> params,
    required List<int> intermediates,
    required int finalByte,
    required bool ignore,
  }) {
    events.add(
      CsiDispatchEvent(
        params: params.map(List<int>.of).toList(),
        intermediates: List<int>.of(intermediates),
        finalByte: finalByte,
        ignore: ignore,
      ),
    );
  }

  @override
  void onOscDispatch({
    required List<List<int>> params,
    required bool bellTerminated,
  }) {
    events.add(
      OscDispatchEvent(
        params: params.map(List<int>.of).toList(),
        bellTerminated: bellTerminated,
      ),
    );
  }

  @override
  void onDcsHook({
    required List<List<int>> params,
    required List<int> intermediates,
    required int finalByte,
    required bool ignore,
  }) {
    events.add(
      DcsHookEvent(
        params: params.map(List<int>.of).toList(),
        intermediates: List<int>.of(intermediates),
        finalByte: finalByte,
        ignore: ignore,
      ),
    );
  }

  @override
  void onDcsPut(int byte) => events.add(DcsPutEvent(byte));

  @override
  void onDcsUnhook() => events.add(const DcsUnhookEvent());
}
