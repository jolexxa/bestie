import 'package:command_protocol/command_protocol.dart';
import 'package:test/test.dart';

final class _PlainPane extends Pane {
  const _PlainPane();

  @override
  String get title => 'Plain';

  @override
  Stream<PaneContent> content(String query) =>
      Stream.value(const PaneContent.empty());
}

Future<PaneActionResult> _stay() async => const PaneStay();

void main() {
  group('Pane', () {
    test('defaults to a fuzzy filter, palette wording and no status', () async {
      const pane = _PlainPane();
      expect(pane.title, 'Plain');
      expect(pane.placeholder, isNull);
      expect(pane.filter, PaneFilter.fuzzy);
      expect(pane.backLabel, 'Back');
      expect(await pane.status.isEmpty, isTrue);
      expect((await pane.content('').first).sections, isEmpty);
    });
  });

  group('PaneContent', () {
    test('flattens rows across sections in order', () {
      const content = PaneContent([
        PaneSection(
          title: 'Downloading',
          count: 1,
          rows: [PaneRow(id: 'a', label: 'Alpha')],
        ),
        PaneSection(
          rows: [
            PaneRow(id: 'b', label: 'Beta'),
            PaneRow(id: 'c', label: 'Gamma'),
          ],
        ),
      ]);
      expect(content.rows.map((row) => row.id), ['a', 'b', 'c']);
      expect(content.sections.first.title, 'Downloading');
      expect(content.sections.first.count, 1);
      expect(content.sections.last.title, isNull);
      expect(const PaneContent.empty().rows, isEmpty);
    });

    test('a section keeps its header and columns when rows are swapped', () {
      const section = PaneSection(
        title: 'Quants',
        count: 2,
        columns: [
          PaneColumn(title: 'Quant', width: 8),
          PaneColumn(title: 'Size', width: 7, align: PaneAlign.end),
          PaneColumn(),
        ],
        rows: [PaneRow(id: 'a', label: 'Alpha')],
      );
      final swapped = section.withRows(const [PaneRow(id: 'b', label: 'B')]);
      expect(section.notes, isEmpty);
      expect(swapped.title, 'Quants');
      expect(swapped.count, 2);
      expect(swapped.columns, same(section.columns));
      expect(swapped.rows.single.id, 'b');
      expect(section.columns.last.width, isNull);
      expect(section.columns.last.title, '');
      expect(section.columns.last.align, PaneAlign.start);
      expect(section.columns[1].align, PaneAlign.end);
    });
  });

  group('PaneNote', () {
    test('a section keeps its notes when rows are swapped', () {
      const section = PaneSection(
        notes: [
          PaneNote([PaneSpan('No local models yet.', PaneTone.emphasis)]),
          PaneNote.blank(),
        ],
        rows: [PaneRow(id: 'a', label: 'Alpha')],
      );
      final swapped = section.withRows(const []);
      expect(swapped.notes, same(section.notes));
      expect(swapped.notes.first.spans.single.text, 'No local models yet.');
      expect(swapped.notes.last.spans, isEmpty);
    });
  });

  group('PaneRow', () {
    test('defaults to a plain, single-line, glyphless row', () {
      const row = PaneRow(id: 'a', label: 'Alpha');
      expect(row.glyph, isNull);
      expect(row.glyphTone, PaneTone.secondary);
      expect(row.labelTone, PaneTone.plain);
      expect(row.cells, isEmpty);
      expect(row.trailing, isEmpty);
      expect(row.detail, isEmpty);
      expect(row.progress, isNull);
      expect(row.actions, isEmpty);
      expect(row.tint, PaneTint.none);
      expect(row.keywords, 'Alpha');
      expect(
        const PaneRow(id: 'b', label: 'B', keywords: 'beta').keywords,
        'beta',
      );
    });

    test('finds the action bound to a key', () {
      const open = PaneAction.primary(label: 'Open', invoke: _stay);
      const delete = PaneAction(
        key: CharKey('d'),
        label: 'Delete',
        invoke: _stay,
        danger: true,
      );
      const row = PaneRow(id: 'a', label: 'Alpha', actions: [open, delete]);
      expect(row.actionFor(const PrimaryKey()), same(open));
      expect(row.actionFor(const CharKey('d')), same(delete));
      expect(row.actionFor(const CharKey('x')), isNull);
      expect(open.primary, isTrue);
      expect(open.danger, isFalse);
      expect(delete.primary, isFalse);
      expect(delete.danger, isTrue);
    });
  });

  group('PaneKey', () {
    test('compares by the key pressed', () {
      expect(const PrimaryKey(), const PrimaryKey());
      expect(const PrimaryKey().hashCode, const PrimaryKey().hashCode);
      expect(const CharKey('d'), const CharKey('d'));
      expect(const CharKey('d').hashCode, const CharKey('d').hashCode);
      expect(const CharKey('d'), isNot(const CharKey('x')));
      expect(const CharKey('d'), isNot(const PrimaryKey()));
      expect(const PrimaryKey(), isNot(const CharKey('d')));
    });
  });

  group('PaneProgress', () {
    test('a fraction keeps its value between 0 and 1', () {
      expect(const PaneFraction(0.5).clamped, 0.5);
      expect(const PaneFraction(1.7).clamped, 1);
      expect(const PaneFraction(-1).clamped, 0);
      expect(const PaneFraction(0.5, label: 'half').label, 'half');
    });

    test('an indeterminate bar carries an optional label', () {
      expect(const PaneIndeterminate().label, isNull);
      expect(const PaneIndeterminate(label: 'Reading').label, 'Reading');
    });
  });

  group('PaneStatus', () {
    test('defaults to a muted, glyphless band without progress', () {
      const status = PaneStatus(spans: [PaneSpan('Idle')]);
      expect(status.glyph, isNull);
      expect(status.glyphTone, PaneTone.muted);
      expect(status.trailing, isEmpty);
      expect(status.progress, isNull);
      expect(status.actions, isEmpty);
      expect(status.spans.single.tone, PaneTone.plain);
      expect(const PaneSpan('x', PaneTone.danger).tone, PaneTone.danger);
    });

    test('finds its actions by key', () {
      final retry = PaneAction(
        key: const CharKey('r'),
        label: 'Retry',
        invoke: () async => const PaneStay(),
      );
      final status = PaneStatus(spans: const [], actions: [retry]);

      expect(status.actionFor(const CharKey('r')), same(retry));
      expect(status.actionFor(const CharKey('x')), isNull);
      expect(status.actionFor(const PrimaryKey()), isNull);
    });
  });

  group('PaneActionResult', () {
    test('results carry what the palette needs', () async {
      final command = Command(
        id: 'models.delete',
        title: 'Delete',
        description: '',
        group: 'Models',
        availability: alwaysAvailable(),
        body: CommandFlow(invoke: (_) async => const CommandRan()),
      );
      final labels = [
        for (final result in <PaneActionResult>[
          const PaneStay(),
          const PaneClose(),
          const PanePop(),
          const PaneRejected('busy'),
          const PanePush(_PlainPane()),
          PaneOpenCommand(command),
        ])
          switch (result) {
            PaneStay() => 'stay',
            PaneClose() => 'close',
            PanePop() => 'pop',
            PaneRejected(:final reason) => reason,
            PanePush(:final pane) => pane.title,
            PaneOpenCommand(:final command) => command.id,
          },
      ];
      expect(labels, [
        'stay',
        'close',
        'pop',
        'busy',
        'Plain',
        'models.delete',
      ]);
      expect(await _stay(), isA<PaneStay>());
    });

    test('a command opens its pane in place of a flow', () {
      final command = Command(
        id: 'models.installed',
        title: 'Installed models',
        description: '',
        group: 'Models',
        availability: alwaysAvailable(),
        body: const CommandPane(_PlainPane()),
      );
      final title = switch (command.body) {
        CommandFlow() => 'flow',
        CommandPane(:final pane) => pane.title,
      };
      expect(title, 'Plain');
    });
  });
}
