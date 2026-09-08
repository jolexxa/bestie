import 'dart:convert';
import 'dart:typed_data';

import 'package:sandbox/src/lowering/lowered_policy.dart';
import 'package:sandbox/src/sandbox_spec.dart';

/// The wire magic and version. A mismatch fails closed in `bestie_guard`.
const wireMagic = 'sandbox/1';

/// Encodes [policy] and [network] as the NUL-delimited grant program the
/// native confine step reads off `--confine-fd`.
Uint8List encodeWire(LoweredPolicy policy, NetworkTier network) {
  final builder = BytesBuilder();
  void field(String value) {
    builder
      ..add(utf8.encode(value))
      ..addByte(0);
  }

  field(wireMagic);
  field(network.name);

  final grants = switch (policy) {
    GrantProgram(:final grants) => grants,
    MaskedProgram(:final grants) => grants,
  };
  for (final grant in grants) {
    field(switch (grant.access) {
      GrantAccess.read => 'r',
      GrantAccess.readWrite => 'rw',
      GrantAccess.listDir => 'l',
    });
    field(grant.path);
  }

  if (policy is MaskedProgram) {
    for (final deny in policy.denies) {
      field('d');
      field(deny.path);
    }
  }

  return builder.toBytes();
}
