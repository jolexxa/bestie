import 'package:intentions/intentions.dart';

/// Turn-shaping values every agent this repository owns runs under.
///
/// Supplied rather than defaulted: what these should be is a configuration
/// question, and answering it is not this layer's to do. Revised from above
/// whenever configuration changes, and read the next time a turn needs them.
@model
final class AgentConfiguration {
  const AgentConfiguration({
    required this.compactionRatio,
    required this.maxToolCallCharacters,
  });

  /// Fraction of the compaction limit at which a turn folds its history.
  final double compactionRatio;

  /// Ceiling on what one tool result may put into the conversation, whatever
  /// context is free.
  final int maxToolCallCharacters;
}
