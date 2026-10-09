/// The local inference server: OpenAI-compatible chat completions over the
/// completion runtime, plus bestie's owner session, agent leases, and model
/// loading, behind a singleton lock.
library;

export 'src/engine/isolated_engine_starter.dart';
export 'src/inference_lock.dart';
export 'src/inference_server.dart';
export 'src/lifetime/server_lifetime.dart';
export 'src/lifetime/server_stop_reason.dart';
export 'src/model_engine.dart';
export 'src/model_host.dart';
export 'src/model_index_reader.dart';
export 'src/owner_session.dart';
export 'src/server_launch.dart';
export 'src/server_log.dart';
