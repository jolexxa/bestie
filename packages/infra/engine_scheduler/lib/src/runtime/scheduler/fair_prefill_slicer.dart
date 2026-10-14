part of 'sequence_scheduler.dart';

const int fairPrefillMinimumWeight = 1;

final class FairPrefillStream {
  const FairPrefillStream({
    required this.key,
    required this.remainingTokenCount,
    required this.weight,
  });

  final Object key;

  final int remainingTokenCount;

  final int weight;
}

final class FairPrefillSlicer {
  FairPrefillSlicer({this.minimumWeight = fairPrefillMinimumWeight})
    : assert(minimumWeight > 0, 'minimumWeight must be positive');

  final int minimumWeight;
  final Map<Object, int> _debt = {};

  List<int> allocate({
    required int maxBatchTokens,
    required List<FairPrefillStream> streams,
  }) {
    final slices = List<int>.filled(streams.length, 0);
    final activeKeys = <Object>{};
    final activeIndexes = <int>[];
    var totalWeight = 0;
    var totalRemaining = 0;

    for (var index = 0; index < streams.length; index++) {
      final stream = streams[index];
      if (stream.remainingTokenCount <= 0) continue;
      activeKeys.add(stream.key);
      activeIndexes.add(index);
      final weight = _weightFor(stream);
      totalWeight += weight;
      totalRemaining += stream.remainingTokenCount;
    }
    _debt.removeWhere((key, _) => !activeKeys.contains(key));

    if (activeIndexes.isEmpty || maxBatchTokens <= 0) return slices;

    final capacity = _minInt(maxBatchTokens, totalRemaining);
    for (final index in activeIndexes) {
      final stream = streams[index];
      _debt[stream.key] =
          (_debt[stream.key] ?? 0) + capacity * _weightFor(stream);
    }

    var remainingCapacity = capacity;
    while (remainingCapacity > 0) {
      final selected = _selectStream(
        streams,
        activeIndexes: activeIndexes,
        slices: slices,
      );
      if (selected == null) break;
      final stream = streams[selected];
      slices[selected] += 1;
      _debt[stream.key] = (_debt[stream.key] ?? 0) - totalWeight;
      remainingCapacity -= 1;
    }
    return slices;
  }

  int _weightFor(FairPrefillStream stream) {
    return _clampMin(stream.weight, minimumWeight);
  }

  int? _selectStream(
    List<FairPrefillStream> streams, {
    required List<int> activeIndexes,
    required List<int> slices,
  }) {
    int? selected;
    var selectedDebt = 0;
    var selectedWeight = 0;
    for (final index in activeIndexes) {
      final stream = streams[index];
      if (slices[index] >= stream.remainingTokenCount) continue;
      final debt = _debt[stream.key] ?? 0;
      final weight = _weightFor(stream);
      if (selected == null ||
          debt > selectedDebt ||
          (debt == selectedDebt && weight > selectedWeight)) {
        selected = index;
        selectedDebt = debt;
        selectedWeight = weight;
      }
    }
    return selected;
  }
}
