/// Runs chat completions for leased agents on one loaded model: leases
/// sequences, formats and tokenizes prompts, drives the batching scheduler,
/// and streams typed completion events.
library;

export 'src/completion_runtime.dart';
export 'src/models/agent_lease_models.dart';
export 'src/models/completion_models.dart';
