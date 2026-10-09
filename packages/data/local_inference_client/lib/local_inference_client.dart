/// Finds or starts bestie's local inference server, holds its owner
/// session, and serves its models as the `local` provider.
library;

export 'src/local_inference_client.dart' show LocalInferenceClient;
export 'src/models/local_provider_options.dart'
    show LocalProviderOptions, LocalProviderOptionsReader;
export 'src/models/local_server_connection.dart'
    show
        LocalServerAttached,
        LocalServerAttaching,
        LocalServerBusy,
        LocalServerConnection,
        LocalServerDisconnected,
        LocalServerSpawnFailed,
        LocalServerVersionMismatch;
export 'src/models/local_server_launch.dart' show LocalServerLaunch;
export 'src/models/server_results.dart'
    show
        ModelLoadFailed,
        ModelLoadResult,
        ModelLoaded,
        ServerSpawnRefused,
        ServerSpawnResult,
        ServerSpawned;
export 'src/server_spawner.dart' show ServerSpawner;
