import 'dart:async';

import 'package:local_models_repository/local_models_repository.dart';
import 'package:local_models_repository/src/scan/model_scanner.dart';
import 'package:local_models_repository/src/scan/scan_input.dart';
import 'package:local_models_repository/src/scan/scan_logic.dart';
import 'package:local_models_repository/src/scan/scan_output.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../support/fixtures.dart';

class _MockScanner extends Mock implements ModelScanner {}

void main() {
  late _MockScanner scanner;
  late ScanLogic logic;
  late List<List<LocalModel>> published;
  late List<Completer<List<LocalModel>>> scans;

  setUp(() {
    scanner = _MockScanner();
    scans = [];
    when(() => scanner.scan(any())).thenAnswer((_) {
      final scan = Completer<List<LocalModel>>();
      scans.add(scan);
      return scan.future;
    });
    logic = ScanLogic(scanner)..start();
    published = [];
    logic.bind().onOutput<ScanPublished>(
      (output) => published.add(output.models),
    );
  });

  tearDown(() => logic.dispose());

  test('rests until asked', () {
    expect(logic.value, isA<ScanIdleState>());
    expect(logic.value.scanning, isFalse);
    verifyNever(() => scanner.scan(any()));
  });

  test('scans the roots asked for and publishes what it finds', () async {
    logic.input(const RescanRequested(['/models', '/mine']));

    expect(logic.value, isA<ScanRunningState>());
    expect(logic.value.scanning, isTrue);
    verify(() => scanner.scan(['/models', '/mine'])).called(1);

    final model = supportedModel();
    scans.single.complete([model]);
    await logic.task;

    expect(published, [
      [model],
    ]);
    expect(logic.value, isA<ScanIdleState>());
  });

  test('folds requests made mid-scan into one more scan', () async {
    logic
      ..input(const RescanRequested(['/a']))
      ..input(const RescanRequested(['/b']))
      ..input(const RescanRequested(['/c']));

    expect(logic.value, isA<ScanStaleState>());
    expect(logic.value.scanning, isTrue);

    scans.first.complete([unsupportedModel()]);
    await pumpEventQueue();

    expect(published, isEmpty);
    expect(logic.value, isA<ScanRunningState>());
    verify(() => scanner.scan(['/c'])).called(1);
    verifyNever(() => scanner.scan(['/b']));

    final model = supportedModel();
    scans.last.complete([model]);
    await logic.task;

    expect(published, [
      [model],
    ]);
    expect(scans, hasLength(2));
  });

  test('says why when a scan throws, publishing nothing', () async {
    final failures = <String>[];
    logic.bind().onOutput<ScanFailed>((output) => failures.add(output.error));
    logic.input(const RescanRequested(['/a']));

    scans.single.completeError(StateError('isolate died'));
    await logic.task;

    expect(published, isEmpty);
    expect(failures, ['Bad state: isolate died']);
    expect(logic.value, isA<ScanIdleState>());
  });

  test('starts over when a stale scan throws', () async {
    logic
      ..input(const RescanRequested(['/a']))
      ..input(const RescanRequested(['/b']));

    scans.first.completeError(StateError('isolate died'));
    await pumpEventQueue();

    expect(logic.value, isA<ScanRunningState>());
    verify(() => scanner.scan(['/b'])).called(1);

    scans.last.complete(const []);
    await logic.task;

    expect(published, [isEmpty]);
  });
}
