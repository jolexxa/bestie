import 'package:command_protocol/command_protocol.dart';
import 'package:test/test.dart';

void main() {
  group('ConfirmParam', () {
    test('exposes a typed bool key through the sealed base', () {
      const param = ConfirmParam(
        key: ParamKey('confirm'),
        label: 'Delete model?',
        danger: true,
      );
      const Param base = param;
      expect(base.key, const ParamKey<bool>('confirm'));
      expect(param.danger, isTrue);
    });

    test('is not dangerous by default', () {
      const param = ConfirmParam(key: ParamKey('confirm'), label: 'Proceed?');
      expect(param.danger, isFalse);
    });
  });

  group('TextParam', () {
    test('exposes typed key through the sealed base', () {
      const param = TextParam(
        key: ParamKey('name'),
        label: 'Name',
        hint: 'e.g. my-model',
      );
      const Param base = param;
      expect(base.key, const ParamKey<String>('name'));
      expect(param.hint, 'e.g. my-model');
      expect(param.validate, isNull);
    });

    test('validate reports problems', () {
      final param = TextParam(
        key: const ParamKey('name'),
        label: 'Name',
        validate: (value) => value.isEmpty ? 'required' : null,
      );
      expect(param.validate!(''), 'required');
      expect(param.validate!('ok'), isNull);
    });
  });

  group('NumberParam', () {
    test('carries typed bounds', () {
      const param = NumberParam<int>(
        key: ParamKey('threads'),
        label: 'Threads',
        min: 1,
        max: 32,
      );
      expect(param.min, 1);
      expect(param.max, 32);
      expect(param, isA<NumberParam<int>>());
      expect(param, isNot(isA<NumberParam<double>>()));
    });
  });

  group('Option', () {
    test('detail is optional', () {
      const bare = Option(value: 1, label: 'one');
      const detailed = Option(value: 2, label: 'two', detail: 'the second');
      expect(bare.detail, isNull);
      expect(detailed.detail, 'the second');
    });

    test('keywords fall back to the label', () {
      const bare = Option(value: 1, label: 'one');
      const tagged = Option(value: 2, label: 'two', keywords: 'two second');
      expect(bare.keywords, 'one');
      expect(tagged.keywords, 'two second');
    });
  });

  group('ChoiceParam', () {
    test('fixed options are re-listenable', () async {
      final param = ChoiceParam<String>.fixed(
        key: const ParamKey('quant'),
        label: 'Quantization',
        options: const [
          Option(value: 'q4', label: 'Q4_K_M'),
          Option(value: 'q8', label: 'Q8_0'),
        ],
      );
      expect(param.filter, isA<FuzzyFilter>());
      final first = await param.options.first;
      final second = await param.options.first;
      expect(first.map((o) => o.value), ['q4', 'q8']);
      expect(second.map((o) => o.label), ['Q4_K_M', 'Q8_0']);
    });

    test('streamed options pass through', () async {
      final param = ChoiceParam<int>(
        key: const ParamKey('port'),
        label: 'Port',
        options: Stream.value(const [Option(value: 8080, label: '8080')]),
        filter: const NoFilter(),
      );
      expect(param.filter, isA<NoFilter>());
      final options = await param.options.first;
      expect(options.single.value, 8080);
    });
  });

  group('ChoiceParam.searchable', () {
    test('lists the empty query first and hands later queries on', () async {
      final queries = <String>[];
      final param = ChoiceParam<int>.searchable(
        key: const ParamKey('port'),
        label: 'Port',
        search: (query) {
          queries.add(query);
          return Stream.value([Option(value: query.length, label: query)]);
        },
      );

      expect(queries, ['']);
      expect((await param.options.first).single.value, 0);

      final filter = param.filter as SearchFilter<int>;
      expect((await filter.search('ab').first).single.value, 2);
      expect(queries, ['', 'ab']);
    });
  });

  group('MultiChoiceParam', () {
    test('fixed options are re-listenable and bounded', () async {
      final param = MultiChoiceParam<String>.fixed(
        key: const ParamKey('files'),
        label: 'Files',
        options: const [Option(value: 'a', label: 'a.md')],
        min: 1,
        max: 2,
      );
      expect(param.min, 1);
      expect(param.max, 2);
      final first = await param.options.first;
      final second = await param.options.first;
      expect(first.single.value, 'a');
      expect(second.single.label, 'a.md');
    });

    test('streamed options pass through', () async {
      final param = MultiChoiceParam<int>(
        key: const ParamKey('ids'),
        label: 'Ids',
        options: Stream.value(const [Option(value: 1, label: 'one')]),
      );
      final options = await param.options.first;
      expect(options.single.label, 'one');
    });

    test('answerFor keeps the answer list typed for Answers.get', () {
      const files = ParamKey<List<String>>('files');
      final param = MultiChoiceParam<String>.fixed(
        key: files,
        label: 'Files',
        options: const [
          Option(value: 'a', label: 'a.md'),
          Option(value: 'b', label: 'b.md'),
          Option(value: 'c', label: 'c.md'),
        ],
      );
      const options = [
        Option(value: 'a', label: 'a.md'),
        Option(value: 'b', label: 'b.md'),
        Option(value: 'c', label: 'c.md'),
      ];
      final answer = param.answerFor(options, [0, 2]);
      final answers = const Answers.empty().put(files, answer);
      expect(answers.get(files), ['a', 'c']);
      expect(answers.get(files), isA<List<String>>());
    });
  });
}
