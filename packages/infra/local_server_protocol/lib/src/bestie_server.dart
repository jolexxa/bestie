/// The name bestie shows for its local inference server.
const bestieServerName = 'Bestie Server';

/// Why this bestie can't use the server another bestie holds.
String bestieServerBusyMessage(int ownerPid) =>
    'Another bestie (pid $ownerPid) is using $bestieServerName. '
    'Close it to use it here.';
