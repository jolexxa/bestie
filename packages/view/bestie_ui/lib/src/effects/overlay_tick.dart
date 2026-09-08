/// Standard tick rate for all theme effect overlays.
///
/// Animation speed is driven by per-frame deltas (rows/cols-per-tick),
/// NOT by varying this value. Keeping the tick consistent across all
/// overlays makes timing predictable and easier to reason about.
const Duration overlayTickInterval = Duration(milliseconds: 90);
