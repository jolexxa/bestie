/// Claim-aware sequence runtime over `inference`.
///
/// Turns the raw KV verbs of an inference [Context] (acquire, clear,
/// removeRange, stepBatch, ...) into claim-aware, batched, fairly-scheduled
/// sequence operations: allocation, scheduling, and materialization on a
/// shared KV heap. Knows nothing about agents or transcripts — only
/// sequences, leases, and claims.
library;

import 'package:inference/inference.dart' show Context;

export 'src/runtime/lease_allocator.dart';
export 'src/runtime/models/lease_allocator_result.dart';
export 'src/runtime/scheduler/models/sequence_scheduler_result.dart';
export 'src/runtime/scheduler/sequence_scheduler.dart';
