import 'dart:convert';
import 'dart:typed_data';

import 'package:sandbox/src/lowering/lowered_policy.dart';
import 'package:sandbox/src/lowering/wire.dart';
import 'package:sandbox/src/sandbox_spec.dart';
import 'package:test/test.dart';

List<String> fields(Uint8List bytes) {
  final parts = utf8.decode(bytes).split('\x00');
  if (parts.isNotEmpty && parts.last.isEmpty) parts.removeLast();
  return parts;
}

void main() {
  group('encodeWire', () {
    test('opens with the versioned magic and the network tier', () {
      final bytes = encodeWire(const GrantProgram([]), NetworkTier.local);
      expect(fields(bytes), [wireMagic, 'local']);
    });

    test('emits r, rw, and l grant records', () {
      final bytes = encodeWire(
        const GrantProgram([
          Grant('/usr', GrantAccess.read),
          Grant('/w', GrantAccess.readWrite),
          Grant('/home/joanna', GrantAccess.listDir),
        ]),
        NetworkTier.all,
      );
      expect(fields(bytes), [
        wireMagic,
        'all',
        'r',
        '/usr',
        'rw',
        '/w',
        'l',
        '/home/joanna',
      ]);
    });

    test('a masked program emits d records after grants', () {
      final bytes = encodeWire(
        const MaskedProgram(
          [Grant('/w', GrantAccess.readWrite)],
          [Deny('/home/.ssh')],
        ),
        NetworkTier.all,
      );
      expect(fields(bytes), [wireMagic, 'all', 'rw', '/w', 'd', '/home/.ssh']);
    });

    test('a grant program never emits a d record', () {
      final bytes = encodeWire(
        const GrantProgram([Grant('/w', GrantAccess.readWrite)]),
        NetworkTier.none,
      );
      expect(fields(bytes), isNot(contains('d')));
    });
  });
}
