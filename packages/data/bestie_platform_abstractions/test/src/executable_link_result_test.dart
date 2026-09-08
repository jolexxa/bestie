import 'package:bestie_platform_abstractions/bestie_platform_abstractions.dart';
import 'package:test/test.dart';

void main() {
  test('a created result is distinct from a failure', () {
    const created = ExecutableLinkCreated();
    expect(created, isA<ExecutableLinkResult>());
  });

  test('a failure carries its reason', () {
    const failed = ExecutableLinkFailed('link path already exists');
    expect(failed, isA<ExecutableLinkResult>());
    expect(failed.reason, 'link path already exists');
  });
}
