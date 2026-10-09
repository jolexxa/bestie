import 'package:bestie_local_models_use_case/src/wording/units.dart';
import 'package:test/test.dart';

void main() {
  test('bytesLabel reads gigabytes with two decimals and megabytes whole', () {
    expect(bytesLabel(4970000000), '4.97 GB');
    expect(bytesLabel(15000000000), '15.00 GB');
    expect(bytesLabel(512400000), '512 MB');
  });

  test('wholeGigabytesLabel rounds to whole gigabytes', () {
    expect(wholeGigabytesLabel(24 * 1000 * 1000 * 1000), '24 GB');
    expect(wholeGigabytesLabel(17600000000), '18 GB');
  });

  test('speedLabel reads megabytes a second', () {
    expect(speedLabel(48300000), '48.3 MB/s');
  });

  test('countLabel shortens millions and thousands', () {
    expect(countLabel(2400000), '2.4M');
    expect(countLabel(988000), '988K');
    expect(countLabel(612), '612');
    expect(countLabel(120000000), '120M');
  });

  test('parametersLabel reads billions, and millions below a billion', () {
    expect(parametersLabel(7500000000), '7.5B');
    expect(parametersLabel(20900000000), '20.9B');
    expect(parametersLabel(106000000000), '106B');
    expect(parametersLabel(350000000), '350M');
  });

  test('groupedLabel groups thousands with commas', () {
    expect(groupedLabel(32768), '32,768');
    expect(groupedLabel(1048576), '1,048,576');
    expect(groupedLabel(512), '512');
  });

  test('contextLabel reads thousands of tokens', () {
    expect(contextLabel(131072), '128k');
  });

  test('remainingLabel words what is left', () {
    expect(remainingLabel(const Duration(seconds: 20)), 'under a minute left');
    expect(remainingLabel(const Duration(minutes: 2)), 'about 2 min left');
    expect(
      remainingLabel(const Duration(hours: 1, minutes: 5)),
      'about 1 h 5 min left',
    );
  });
}
