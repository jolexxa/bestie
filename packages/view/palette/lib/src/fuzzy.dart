import 'package:fuzzy/fuzzy.dart';

/// Ranks [candidates] against [query] using the `fuzzy` package, keeping
/// matches scoring at least as well as [threshold] (0 is exact, 1 matches
/// anything).
List<int> fuzzyRank(
  String query,
  List<String> candidates, {
  double threshold = 0.6,
}) {
  final fuse = Fuzzy<int>(
    [for (var i = 0; i < candidates.length; i++) i],
    options: FuzzyOptions(
      threshold: threshold,
      keys: [
        WeightedKey(
          name: 'text',
          getter: (index) => candidates[index],
          weight: 1,
        ),
      ],
    ),
  );
  return [for (final result in fuse.search(query)) result.item];
}
