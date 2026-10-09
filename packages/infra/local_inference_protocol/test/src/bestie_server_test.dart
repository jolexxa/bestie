import 'package:local_inference_protocol/local_inference_protocol.dart';
import 'package:test/test.dart';

void main() {
  test('names the server and who holds it when another bestie does', () {
    expect(
      bestieServerBusyMessage(4121),
      'Another bestie (pid 4121) is using Bestie Server. '
      'Close it to use it here.',
    );
  });
}
