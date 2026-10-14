import 'package:local_server_protocol/local_server_protocol.dart';
import 'package:process_host/process_host.dart';
import 'package:test/test.dart';

void main() {
  test('names the server and who holds it when another bestie does', () {
    expect(
      bestieServerBusyMessage(4121),
      'Another bestie (pid 4121) is using Bestie Server. '
      'Close it to use it here.',
    );
  });

  test('says what the server did when its process ended', () {
    final exits = {
      const ProcessSignaled(2): 'was interrupted (SIGINT)',
      const ProcessSignaled(6): 'aborted (SIGABRT)',
      const ProcessSignaled(9): 'was killed (SIGKILL)',
      const ProcessSignaled(11): 'crashed (SIGSEGV)',
      const ProcessSignaled(15): 'was terminated (SIGTERM)',
      const ProcessSignaled(42): 'ended by signal 42',
      const ProcessExited(0): 'exited',
      const ProcessExited(69): 'could not listen on loopback',
      const ProcessExited(70): 'lost its engine',
      const ProcessExited(72): 'could not find its llama.cpp libraries',
      const ProcessExited(73): 'could not open its lock file',
      const ProcessExited(75): 'found another server running',
      const ProcessExited(3): 'exited with code 3',
      const ProcessUnknown(): 'ended in a way bestie could not read',
      const ProcessSupervisorLost(): 'ended without its exit being reported',
    };

    for (final MapEntry(key: exit, value: message) in exits.entries) {
      expect(bestieServerExitMessage(exit), message, reason: '$exit');
    }
  });
}
