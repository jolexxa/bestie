/// The built-in inference server as a feature: starting and stopping it,
/// how it loads models, and what it is doing right now.
library;

export 'src/built_in_server_repository.dart' show BuiltInServerRepository;
export 'src/models/built_in_server_status.dart'
    show
        BuiltInServerStatus,
        ServerFailed,
        ServerFitting,
        ServerIdle,
        ServerIncompatible,
        ServerLoading,
        ServerModelFailed,
        ServerOffline,
        ServerRunning,
        ServerServing,
        ServerStarting,
        ServerTaken;
