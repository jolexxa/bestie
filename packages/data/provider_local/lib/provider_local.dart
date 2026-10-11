/// Finds or starts bestie's local inference server, holds its owner
/// session, and serves its models as the `local` provider.
library;

export 'src/local_provider.dart' show LocalProvider;
export 'src/models/local_server_launch.dart' show LocalServerLaunch;
