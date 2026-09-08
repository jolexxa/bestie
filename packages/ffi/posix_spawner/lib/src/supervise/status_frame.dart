import 'dart:typed_data';

/// Assembles the supervisor's two fixed 4-byte native-endian frames —
/// `[target_pid][raw_status]` — from arbitrarily-chunked reads. Pure and
/// synchronous: the status-pipe read loop feeds it bytes as they arrive off
/// the fd; tests feed it byte arrays directly.
class SupervisorFrameBuffer {
  final List<int> _bytes = <int>[];

  /// True once the first (pid) frame — 4 bytes — has arrived.
  bool get hasPid => _bytes.length >= 4;

  /// True once both frames — 8 bytes — have arrived.
  bool get isComplete => _bytes.length >= 8;

  /// Bytes still needed to complete both frames. The read loop requests
  /// exactly this many each time, so it never over-reads.
  int get remaining => 8 - _bytes.length;

  /// The target pid, decoded from the first frame. Valid once [hasPid].
  int get targetPid => _readHostInt32(_bytes, 0);

  /// The raw `waitpid` status, decoded from the second frame. Valid once
  /// [isComplete].
  int get rawStatus => _readHostInt32(_bytes, 4);

  /// Append freshly-read [bytes].
  void add(List<int> bytes) => _bytes.addAll(bytes);
}

/// Decode 4 native-endian bytes at [offset] as a signed 32-bit int — the same
/// byte order the Rust supervisor wrote with `to_ne_bytes` on this host.
int _readHostInt32(List<int> bytes, int offset) {
  final data = ByteData(4);
  for (var i = 0; i < 4; i++) {
    data.setUint8(i, bytes[offset + i]);
  }
  return data.getInt32(0, Endian.host);
}
