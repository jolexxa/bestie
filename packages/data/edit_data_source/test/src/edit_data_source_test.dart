import 'package:bestie_edit/bestie_edit.dart';
import 'package:edit_data_source/edit_data_source.dart';
import 'package:mocktail/mocktail.dart';
import 'package:process_host/process_host.dart';
import 'package:test/test.dart';

class _MockEditProgram extends Mock implements EditProgram {}

class _FakeSandbox implements Sandbox {}

const _request = ReplaceRequest(path: 'a.txt', oldText: 'a', newText: 'b');

void main() {
  setUpAll(() {
    registerFallbackValue(_request);
    registerFallbackValue(_FakeSandbox());
  });

  test('runs the program with the request and sandbox it was given', () async {
    final program = _MockEditProgram();
    final sandbox = _FakeSandbox();
    const run = EditAnswered(EditNoChange());
    when(
      () => program.run(any(), sandbox: any(named: 'sandbox')),
    ).thenAnswer((_) async => run);

    final result = await EditDataSource(
      program: program,
    ).edit(_request, sandbox: sandbox);

    expect(result, same(run));
    verify(() => program.run(_request, sandbox: sandbox)).called(1);
  });
}
