/// Sort direction for list endpoints.
enum SortDirection {
  /// Sort in ascending order.
  ascending(1),

  /// Sort in descending order.
  descending(-1);

  const SortDirection(this.value);

  /// The integer value sent to the API.
  final int value;
}
