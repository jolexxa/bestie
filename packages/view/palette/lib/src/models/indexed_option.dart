import 'package:command_protocol/command_protocol.dart';
import 'package:intentions/intentions.dart';
import 'package:meta/meta.dart';

/// A picker option paired with its index in the param's full option list,
/// so filtered views can act on the original position.
@model
@immutable
final class IndexedOption {
  const IndexedOption({required this.index, required this.option});

  final int index;
  final Option<Object?> option;
}
