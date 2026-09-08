import 'package:bestie_ui/bestie_ui.dart';
import 'package:test/test.dart';

void main() {
  group('asByteSize', () {
    test('formats binary magnitudes with desktop KB/MB/GB labels', () {
      expect((2 * 1024 * 1024 * 1024).asByteSize, '2 GB');
      expect((1536 * 1024 * 1024).asByteSize, '1.5 GB');
      expect(1024.asByteSize, '1 KB');
      expect(512.asByteSize, '512 B');
    });
  });

  group('asByteSizeRange', () {
    test('returns unknown for empty input', () {
      expect(const <int>[].asByteSizeRange, 'unknown size');
    });

    test('collapses equal min and max', () {
      expect(const [1024].asByteSizeRange, '1 KB');
    });

    test('formats a min-max range', () {
      expect(const [1024, 2048].asByteSizeRange, '1 KB-2 KB');
    });
  });

  group('asDuration', () {
    test('sub-second stays in ms', () {
      expect(350.asDuration, '350ms');
    });

    test('a second or more converts to s', () {
      expect(1200.asDuration, '1.2s');
    });
  });

  group('as12HourTime', () {
    test('formats morning, noon, and afternoon', () {
      expect(DateTime.utc(2026, 1, 1, 9, 5).as12HourTime, '9:05 AM');
      expect(DateTime.utc(2026, 1, 1, 0, 30).as12HourTime, '12:30 AM');
      expect(DateTime.utc(2026, 1, 1, 15, 45).as12HourTime, '3:45 PM');
    });
  });

  group('formatDownloadLabel', () {
    test('shows received size and percent', () {
      expect(
        formatDownloadLabel(
          receivedBytes: 512 * 1024 * 1024,
          totalBytes: 1024 * 1024 * 1024,
        ),
        '512 MB (50%)',
      );
    });

    test('handles zero total', () {
      expect(
        formatDownloadLabel(receivedBytes: 0, totalBytes: 0),
        '0 B (0%)',
      );
    });
  });

  group('asByteRate', () {
    test('formats a bytes-per-second rate with desktop labels', () {
      expect((2 * 1024 * 1024).asByteRate, '2 MB/s');
    });
  });

  group('asCompactCount', () {
    test('formats millions, thousands, and small values', () {
      expect(1500000.asCompactCount, '1.5M');
      expect(500000.asCompactCount, '500.0k');
      expect(42.asCompactCount, '42');
    });
  });

  group('asParamCount', () {
    test('scales into billions and trims trailing .0', () {
      expect(20000000000.asParamCount, '20B');
      expect(20900000000.asParamCount, '20.9B');
      expect(8000000000.asParamCount, '8B');
      expect(500000000.asParamCount, '500M');
      expect(1500000.asParamCount, '1.5M');
      expect(2000.asParamCount, '2k');
      expect(42.asParamCount, '42');
    });
  });

  group('withCommas', () {
    test('inserts comma separators', () {
      expect(1234567.withCommas, '1,234,567');
      expect(42.withCommas, '42');
    });
  });

  group('asCompactTokens', () {
    test('formats millions, thousands, and small values', () {
      expect(1500000.asCompactTokens, '1.5M');
      expect(128000.asCompactTokens, '128k');
      expect(512.asCompactTokens, '512');
    });
  });

  group('truncate', () {
    test('passes short text through and truncates long text', () {
      expect('short'.truncate(), 'short');
      expect('abcdef'.truncate(maxLength: 3), 'abc…');
    });
  });
}
