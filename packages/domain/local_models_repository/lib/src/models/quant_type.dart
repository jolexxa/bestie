import 'package:intentions/intentions.dart';

/// How much of a model's quality a quant keeps, best first.
@model
enum QualityTier { overkill, great, good, mediocre, bad, awful }

/// Quants that share a scheme, within which more bits per weight never
/// means less quality.
@model
enum QuantFamily { float, legacy, kQuant, iQuant, ternary, microscaling }

/// Every `general.file_type` bestie can run, with its quality tier.
///
/// [bitsPerWeight] follows llama.cpp's quantize table: the stated bits per
/// weight, or the Llama-3-8B file size in gigabytes, which comes to nearly
/// the same number. The file type ids are llama.cpp's `llama_ftype`.
@model
enum QuantType {
  f32(0, 'F32', QuantFamily.float, 32, QualityTier.overkill),
  f16(1, 'F16', QuantFamily.float, 16, QualityTier.overkill),
  q4Zero(2, 'Q4_0', QuantFamily.legacy, 4.34, QualityTier.good),
  q4One(3, 'Q4_1', QuantFamily.legacy, 4.78, QualityTier.good),
  q8Zero(7, 'Q8_0', QuantFamily.legacy, 7.96, QualityTier.overkill),
  q5Zero(8, 'Q5_0', QuantFamily.legacy, 5.21, QualityTier.great),
  q5One(9, 'Q5_1', QuantFamily.legacy, 5.65, QualityTier.great),
  q2K(10, 'Q2_K', QuantFamily.kQuant, 2.96, QualityTier.bad),
  q3KSmall(11, 'Q3_K_S', QuantFamily.kQuant, 3.41, QualityTier.mediocre),
  q3KMedium(12, 'Q3_K_M', QuantFamily.kQuant, 3.74, QualityTier.good),
  q3KLarge(13, 'Q3_K_L', QuantFamily.kQuant, 4.03, QualityTier.good),
  q4KSmall(14, 'Q4_K_S', QuantFamily.kQuant, 4.37, QualityTier.good),
  q4KMedium(15, 'Q4_K_M', QuantFamily.kQuant, 4.58, QualityTier.great),
  q5KSmall(16, 'Q5_K_S', QuantFamily.kQuant, 5.21, QualityTier.great),
  q5KMedium(17, 'Q5_K_M', QuantFamily.kQuant, 5.33, QualityTier.great),
  q6K(18, 'Q6_K', QuantFamily.kQuant, 6.14, QualityTier.overkill),
  iq2ExtraExtraSmall(19, 'IQ2_XXS', QuantFamily.iQuant, 2.06, QualityTier.bad),
  iq2ExtraSmall(20, 'IQ2_XS', QuantFamily.iQuant, 2.31, QualityTier.bad),
  q2KSmall(21, 'Q2_K_S', QuantFamily.kQuant, 2.96, QualityTier.bad),
  iq3ExtraSmall(22, 'IQ3_XS', QuantFamily.iQuant, 3.3, QualityTier.mediocre),
  iq3ExtraExtraSmall(
    23,
    'IQ3_XXS',
    QuantFamily.iQuant,
    3.06,
    QualityTier.mediocre,
  ),
  iq1Small(24, 'IQ1_S', QuantFamily.iQuant, 1.56, QualityTier.awful),
  iq4NonLinear(25, 'IQ4_NL', QuantFamily.iQuant, 4.5, QualityTier.good),
  iq3Small(26, 'IQ3_S', QuantFamily.iQuant, 3.44, QualityTier.good),
  iq3Medium(27, 'IQ3_M', QuantFamily.iQuant, 3.66, QualityTier.good),
  iq2Small(28, 'IQ2_S', QuantFamily.iQuant, 2.5, QualityTier.mediocre),
  iq2Medium(29, 'IQ2_M', QuantFamily.iQuant, 2.7, QualityTier.mediocre),
  iq4ExtraSmall(30, 'IQ4_XS', QuantFamily.iQuant, 4.25, QualityTier.good),
  iq1Medium(31, 'IQ1_M', QuantFamily.iQuant, 1.75, QualityTier.awful),
  bf16(32, 'BF16', QuantFamily.float, 16, QualityTier.overkill),
  tq1Zero(36, 'TQ1_0', QuantFamily.ternary, 1.69, QualityTier.mediocre),
  tq2Zero(37, 'TQ2_0', QuantFamily.ternary, 2.06, QualityTier.mediocre),
  mxfp4(38, 'MXFP4', QuantFamily.microscaling, 4.25, QualityTier.great);

  const QuantType(
    this.fileType,
    this.label,
    this.family,
    this.bitsPerWeight,
    this.tier,
  );

  /// The `general.file_type` value.
  final int fileType;

  /// The name quant files and pickers use, e.g. `Q4_K_M`.
  final String label;

  final QuantFamily family;

  final double bitsPerWeight;

  final QualityTier tier;

  static final Map<int, QuantType> _byFileType = {
    for (final type in values) type.fileType: type,
  };

  /// Labels quant files use beyond the canonical ones. Mixed `_L` / `_XL`
  /// quants keep a few tensors at higher precision but report their base
  /// type in the header.
  static final Map<String, QuantType> _byLabel = {
    for (final type in values) type.label: type,
    'Q2_K_L': q2K,
    'Q2_K_XL': q2K,
    'Q3_K_XL': q3KMedium,
    'Q4_K_L': q4KMedium,
    'Q4_K_XL': q4KMedium,
    'Q5_K_L': q5KMedium,
    'Q5_K_XL': q5KMedium,
    'Q6_K_L': q6K,
    'Q6_K_XL': q6K,
    'Q8_K_XL': q8Zero,
  };

  static QuantType? fromFileType(int? fileType) => _byFileType[fileType];

  /// The type behind a file name's quant [label], case-insensitively.
  static QuantType? fromLabel(String label) => _byLabel[label.toUpperCase()];
}
