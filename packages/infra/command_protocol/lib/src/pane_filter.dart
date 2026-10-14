/// How a pane narrows its rows as the user types.
enum PaneFilter {
  /// The palette ranks row keywords against what is typed, over the content
  /// the pane lists for the empty query.
  fuzzy,

  /// The pane answers each query itself; the palette lists what comes back,
  /// in order.
  search,

  /// Nothing to type; the pane lists its content for the empty query.
  none,
}
