import 'package:dart_mappable/dart_mappable.dart';
import 'package:intentions/intentions.dart';

/// Whether access to a repository is gated behind approval.
///
/// The HuggingFace API encodes this as either a boolean (`false` for not
/// gated) or a string (`"auto"` or `"manual"`).
enum GatedMode {
  /// The repository is not gated — anyone can access it.
  notGated,

  /// Access requests are automatically approved.
  auto,

  /// Access requests require manual approval.
  manual,
}

/// Mapper for [GatedMode] handling the HuggingFace API's mixed
/// bool/string wire format.
@model
class GatedModeMapper extends SimpleMapper<GatedMode> {
  /// Creates a [GatedModeMapper].
  const GatedModeMapper();

  @override
  GatedMode decode(dynamic value) {
    if (value is bool) return value ? GatedMode.manual : GatedMode.notGated;
    return switch (value) {
      'auto' => GatedMode.auto,
      'manual' => GatedMode.manual,
      _ => GatedMode.notGated,
    };
  }

  @override
  Object encode(GatedMode self) => switch (self) {
    GatedMode.notGated => false,
    GatedMode.auto => 'auto',
    GatedMode.manual => 'manual',
  };
}
