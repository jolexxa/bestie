import 'package:local_models_repository/local_models_repository.dart';
import 'package:test/test.dart';

void main() {
  group('QuantType', () {
    test('finds supported types by header file type', () {
      expect(QuantType.fromFileType(15), QuantType.q4KMedium);
      expect(QuantType.fromFileType(38), QuantType.mxfp4);
      expect(QuantType.fromFileType(0), QuantType.f32);
    });

    test('knows nothing of removed or unknown file types', () {
      expect(QuantType.fromFileType(4), isNull);
      expect(QuantType.fromFileType(33), isNull);
      expect(QuantType.fromFileType(null), isNull);
    });

    test('maps file name labels, mixed quants included, to their base', () {
      expect(QuantType.fromLabel('q4_k_m'), QuantType.q4KMedium);
      expect(QuantType.fromLabel('Q4_K_XL'), QuantType.q4KMedium);
      expect(QuantType.fromLabel('Q6_K_L'), QuantType.q6K);
      expect(QuantType.fromLabel('Q8_K_XL'), QuantType.q8Zero);
      expect(QuantType.fromLabel('BF16'), QuantType.bf16);
      expect(QuantType.fromLabel('NVFP4'), isNull);
      expect(QuantType.fromLabel(''), isNull);
    });

    test('rates the quants the picker shows as the mockup does', () {
      expect(QuantType.q3KLarge.tier, QualityTier.good);
      expect(QuantType.q4KMedium.tier, QualityTier.great);
      expect(QuantType.q5KMedium.tier, QualityTier.great);
      expect(QuantType.q6K.tier, QualityTier.overkill);
      expect(QuantType.q8Zero.tier, QualityTier.overkill);
      expect(QuantType.bf16.tier, QualityTier.overkill);
      expect(QuantType.f16.tier, QualityTier.overkill);
      expect(QuantType.f32.tier, QualityTier.overkill);
      expect(QuantType.iq4ExtraSmall.tier, QualityTier.good);
      expect(QuantType.mxfp4.tier, QualityTier.great);
    });

    test('never rates more bits lower within a family', () {
      for (final family in QuantFamily.values) {
        final types =
            QuantType.values.where((type) => type.family == family).toList()
              ..sort(
                (first, second) =>
                    first.bitsPerWeight.compareTo(second.bitsPerWeight),
              );
        for (var index = 1; index < types.length; index++) {
          final fewer = types[index - 1];
          final more = types[index];
          expect(
            more.tier.index,
            lessThanOrEqualTo(fewer.tier.index),
            reason: '${more.label} is rated below ${fewer.label}',
          );
        }
      }
    });

    test('rates the same quantization the same, however it is named', () {
      for (final label in ['Q4_K_XL', 'Q4_K_L']) {
        expect(QuantType.fromLabel(label)!.tier, QuantType.q4KMedium.tier);
      }
    });

    test('labels every type with a distinct name and file type', () {
      expect(
        QuantType.values.map((type) => type.label).toSet(),
        hasLength(QuantType.values.length),
      );
      expect(
        QuantType.values.map((type) => type.fileType).toSet(),
        hasLength(QuantType.values.length),
      );
    });
  });

  group('ModelFit', () {
    const gigabyte = 1024 * 1024 * 1024;

    test('fits when the weights leave room for context', () {
      expect(
        ModelFit.estimate(
          modelBytes: 5 * gigabyte,
          availableBytes: 24 * gigabyte,
        ),
        ModelFit.fits,
      );
      expect(
        ModelFit.estimate(modelBytes: 60, availableBytes: 100),
        ModelFit.fits,
      );
    });

    test('is tight when little room is left', () {
      expect(
        ModelFit.estimate(modelBytes: 61, availableBytes: 100),
        ModelFit.tight,
      );
      expect(
        ModelFit.estimate(modelBytes: 85, availableBytes: 100),
        ModelFit.tight,
      );
    });

    test('is too big past that, or with no memory reported', () {
      expect(
        ModelFit.estimate(modelBytes: 86, availableBytes: 100),
        ModelFit.tooBig,
      );
      expect(
        ModelFit.estimate(modelBytes: 1, availableBytes: 0),
        ModelFit.tooBig,
      );
      expect(
        ModelFit.estimate(modelBytes: 0, availableBytes: 0),
        ModelFit.tooBig,
      );
    });
  });
}
