import 'package:intentions/intentions.dart';
import 'package:local_inference_protocol/local_inference_protocol.dart';

/// How asking the server to load a model went.
@model
sealed class ModelLoadResult {
  const ModelLoadResult();
}

/// The model serves completions.
@model
final class ModelLoaded extends ModelLoadResult {
  const ModelLoaded(this.ready);

  final ModelReady ready;
}

@model
final class ModelLoadFailed extends ModelLoadResult {
  const ModelLoadFailed(this.reason);

  final String reason;
}

/// How asking the server to unload its model went.
@model
sealed class ModelUnloadResult {
  const ModelUnloadResult();
}

@model
final class ModelUnloadSucceeded extends ModelUnloadResult {
  const ModelUnloadSucceeded();
}

@model
final class ModelUnloadFailed extends ModelUnloadResult {
  const ModelUnloadFailed(this.reason);

  final String reason;
}

/// How starting a server process went.
@model
sealed class ServerSpawnResult {
  const ServerSpawnResult();
}

@model
final class ServerSpawned extends ServerSpawnResult {
  const ServerSpawned({required this.pid});

  final int pid;
}

@model
final class ServerSpawnRefused extends ServerSpawnResult {
  const ServerSpawnRefused(this.reason);

  final String reason;
}
