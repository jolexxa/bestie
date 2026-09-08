import 'dart:typed_data';

import 'package:posix_spawner/src/supervise/status_frame.dart';
import 'package:test/test.dart';

/// The two native-endian frames the Rust supervisor writes, byte-for-byte.
Uint8List _frames(int targetPid, int rawStatus) {
  final data = ByteData(8)
    ..setInt32(0, targetPid, Endian.host)
    ..setInt32(4, rawStatus, Endian.host);
  return data.buffer.asUint8List();
}

void main() {
  group('SupervisorFrameBuffer', () {
    test('decodes both frames delivered in a single chunk', () {
      final buffer = SupervisorFrameBuffer()..add(_frames(4242, 0));

      expect(buffer.hasPid, isTrue);
      expect(buffer.isComplete, isTrue);
      expect(buffer.remaining, 0);
      expect(buffer.targetPid, 4242);
      expect(buffer.rawStatus, 0);
    });

    test('exposes the pid after the first frame, before the second', () {
      final frames = _frames(1234, 256);
      final buffer = SupervisorFrameBuffer()..add(frames.sublist(0, 4));

      expect(buffer.hasPid, isTrue);
      expect(buffer.isComplete, isFalse);
      expect(buffer.remaining, 4);
      expect(buffer.targetPid, 1234);

      buffer.add(frames.sublist(4));
      expect(buffer.isComplete, isTrue);
      expect(buffer.rawStatus, 256);
    });

    test('reassembles across arbitrary chunk boundaries', () {
      final frames = _frames(7, 42);
      final buffer = SupervisorFrameBuffer();

      for (final byte in frames) {
        expect(buffer.isComplete, isFalse);
        buffer.add([byte]);
      }

      expect(buffer.isComplete, isTrue);
      expect(buffer.targetPid, 7);
      expect(buffer.rawStatus, 42);
    });

    test('decodes a signed (high-bit-set) raw status', () {
      final buffer = SupervisorFrameBuffer()..add(_frames(9, -1));

      expect(buffer.rawStatus, -1);
    });

    test('remaining counts down from eight as bytes arrive', () {
      final buffer = SupervisorFrameBuffer();
      expect(buffer.remaining, 8);

      buffer.add(const [0, 0, 0]);
      expect(buffer.remaining, 5);
      expect(buffer.hasPid, isFalse);
    });
  });
}
