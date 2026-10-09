import 'package:inference_server/inference_server.dart';
import 'package:local_inference_protocol/local_inference_protocol.dart';
import 'package:test/test.dart';

void main() {
  late OwnerSessions owners;
  late int minted;

  setUp(() {
    minted = 0;
    owners = OwnerSessions(mintToken: () => 'token-${++minted}');
  });

  test('grants the session to the first client', () {
    final claim = owners.claim(pid: 41) as OwnerGranted;

    expect(claim.owner.token, 'token-1');
    expect(claim.owner.pid, 41);
    expect(owners.owner, same(claim.owner));
  });

  test('refuses a second client, naming the owner', () {
    owners.claim(pid: 41);

    expect(
      owners.claim(pid: 42),
      isA<OwnerRefused>().having((refused) => refused.ownerPid, 'pid', 41),
    );
  });

  test('authorizes only the owner token', () {
    owners.claim(pid: 41);

    expect(owners.authorizes('token-1'), isTrue);
    expect(owners.authorizes('token-2'), isFalse);
    expect(owners.authorizes(null), isFalse);
  });

  test('sends events to the owner and ends them on release', () async {
    final owner = (owners.claim(pid: 41) as OwnerGranted).owner;
    final events = owner.events.toList();

    owners
      ..send(const ModelStatusEvent(status: ModelUnloaded()))
      ..release(owner);

    expect(await events, [isA<ModelStatusEvent>()]);
    expect(owners.owner, isNull);
    expect(owners.authorizes('token-1'), isFalse);
    owner.send(const ModelStatusEvent(status: ModelUnloaded()));
  });

  test('sending without an owner does nothing', () {
    expect(
      () => owners.send(const ModelStatusEvent(status: ModelUnloaded())),
      returnsNormally,
    );
  });

  test('releasing a former owner leaves the current one', () async {
    final first = (owners.claim(pid: 41) as OwnerGranted).owner;
    owners.release(first);
    final second = (owners.claim(pid: 42) as OwnerGranted).owner;

    owners.release(first);

    expect(owners.owner, same(second));
  });
}
