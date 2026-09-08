/// A position in the selectable text, held to the content under it rather
/// than to the offset it happened to sit at.
///
/// Offsets move for reasons unrelated to the position: history evicts off the
/// front, a wrapped line ends and its padding stops being content, a re-wrap
/// lays the text out again. Anything that must stay on its content across
/// those — a selection edge, say — holds an anchor and asks the screen where
/// it is now.
///
/// Opaque: only the screen that handed one out knows where it points, so an
/// anchor from another screen reads back as gone.
class SelectionAnchor {
  /// Screens hand these out; there is nothing to build one from.
  SelectionAnchor();
}
