import 'package:bestie_sandbox_use_case/bestie_sandbox_use_case.dart';
import 'package:bestie_sandbox_use_case/src/write_access_queue.dart';
import 'package:test/test.dart';

WriteAccessRequest _request(String id) => WriteAccessRequest(
  id: id,
  path: '/home/cow/$id',
  shownPath: '~/$id',
  reason: 'because',
  agentId: 'primary',
);

void main() {
  late WriteAccessQueue queue;

  setUp(() => queue = WriteAccessQueue());

  tearDown(() => queue.dispose());

  test('opens empty', () {
    expect(queue.current, isNull);
    expect(queue.stream, emits(isNull));
  });

  test('shows the first ask until it is answered, then the next', () async {
    final seen = <String?>[];
    final sub = queue.stream.map((request) => request?.id).listen(seen.add);

    final first = queue.enqueue(_request('a'));
    final second = queue.enqueue(_request('b'));
    expect(queue.current?.id, 'a');

    queue.answer('a', allow: true);
    expect(queue.current?.id, 'b');
    queue.answer('b', allow: false);
    expect(queue.current, isNull);

    expect(await first, WriteAccessAnswer.allowed);
    expect(await second, WriteAccessAnswer.declined);
    await pumpEventQueue();
    expect(seen, [null, 'a', 'b', null]);
    await sub.cancel();
  });

  test('withdrawing an ask answers it as withdrawn', () async {
    final pending = queue.enqueue(_request('a'));

    queue.withdraw('a');

    expect(await pending, WriteAccessAnswer.withdrawn);
    expect(queue.current, isNull);
  });

  test('withdrawing an ask behind the head leaves the head showing', () async {
    final first = queue.enqueue(_request('a'));
    final second = queue.enqueue(_request('b'));

    queue.withdraw('b');

    expect(queue.current?.id, 'a');
    expect(await second, WriteAccessAnswer.withdrawn);
    queue.answer('a', allow: true);
    expect(await first, WriteAccessAnswer.allowed);
  });

  test('ignores an answer to an ask no longer waiting', () {
    queue
      ..answer('missing', allow: true)
      ..withdraw('missing');

    expect(queue.current, isNull);
  });
}
