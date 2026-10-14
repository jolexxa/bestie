/// Splits [total] into whole parts sized by [weights] that add up to
/// [total]. Every part is zero when the weights are.
List<int> splitProportionally(int total, List<int> weights) {
  final weightSum = weights.fold(0, (sum, weight) => sum + weight);
  if (weightSum == 0) return List.filled(weights.length, 0);
  final parts = <int>[];
  var weightBefore = 0;
  for (final weight in weights) {
    final start = total * weightBefore ~/ weightSum;
    weightBefore += weight;
    parts.add(total * weightBefore ~/ weightSum - start);
  }
  return parts;
}
