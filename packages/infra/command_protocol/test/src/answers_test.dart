import 'package:command_protocol/command_protocol.dart';
import 'package:test/test.dart';

void main() {
  const model = ParamKey<String>('model');
  const quant = ParamKey<String>('quant');
  const threads = ParamKey<int>('threads');

  group('Answers', () {
    test('starts empty', () {
      const answers = Answers.empty();
      expect(answers.isEmpty, isTrue);
      expect(answers.length, 0);
    });

    test('put records values readable by typed key', () {
      final answers = const Answers.empty().put(model, 'llama').put(threads, 8);
      expect(answers.isEmpty, isFalse);
      expect(answers.length, 2);
      expect(answers.get(model), 'llama');
      expect(answers.get(threads), 8);
    });

    test('put replaces an existing key at the end of the order', () {
      final answers = const Answers.empty()
          .put(model, 'llama')
          .put(quant, 'q4')
          .put(model, 'mistral');
      expect(answers.length, 2);
      expect(answers.get(model), 'mistral');
      expect(answers.pop().maybe(model), isNull);
      expect(answers.pop().get(quant), 'q4');
    });

    test('pop removes the most recent answer', () {
      final answers = const Answers.empty()
          .put(model, 'llama')
          .put(quant, 'q4')
          .pop();
      expect(answers.length, 1);
      expect(answers.get(model), 'llama');
      expect(answers.maybe(quant), isNull);
    });

    test('pop on empty stays empty', () {
      const empty = Answers.empty();
      expect(empty.pop(), same(empty));
    });

    test('maybe returns null for unanswered keys', () {
      expect(const Answers.empty().maybe(model), isNull);
    });

    test('get throws for unanswered keys', () {
      expect(
        () => const Answers.empty().get(model),
        throwsArgumentError,
      );
    });
  });
}
