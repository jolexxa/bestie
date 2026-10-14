/// Finds or starts bestie's built-in inference server, holds its owner
/// session, and serves its models as the `local` provider.
library;

export 'src/built_in_server_client.dart' show BuiltInServerClient;
export 'src/local_provider.dart' show LocalProvider;
export 'src/models/built_in_server_connection.dart'
    show
        BuiltInServerAttached,
        BuiltInServerAttaching,
        BuiltInServerBusy,
        BuiltInServerConnection,
        BuiltInServerDisconnected,
        BuiltInServerSpawnFailed,
        BuiltInServerVersionMismatch;
export 'src/models/built_in_server_launch.dart' show BuiltInServerLaunch;
export 'src/models/model_load_options.dart' show ModelLoadOptions;
