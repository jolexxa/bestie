import 'package:config_protocol/config_protocol.dart';
import 'package:test/test.dart';

const _field = NumericField<int>(
  label: 'n',
  description: 'd',
  min: 0,
  max: 10,
  step: 1,
);

ConfigKey<int> _key(String id) => ConfigKey<int>(
  id: id,
  path: [id],
  codec: ConfigCodecs.integers,
  defaultValue: () => 0,
  field: _field,
);

void main() {
  final first = _key('first').global;
  final second = _key('second').global;
  final third = _key('third').at(ConfigScope.path(const ['models', 'qwen']));
  final page = ConfigParamPage(
    id: 'page',
    label: 'Page',
    sections: [
      ConfigSection(heading: 'One', addresses: [first, second]),
      ConfigSection(heading: 'Two', addresses: [third]),
    ],
  );
  final layout = ConfigLayout(
    initialPageId: 'page',
    pages: [
      page,
      ConfigInfoPage(
        id: 'info',
        label: 'Info',
        rowCount: (entryCount) => entryCount + 1,
        visualIndex: (rowIndex, entryCount) => rowIndex + 2,
      ),
      const ConfigDocumentPage(id: 'credits', label: 'Credits'),
    ],
  );

  test('a param page lists its addresses in section order', () {
    expect(page.addresses, [first, second, third]);
  });

  test('finds a page by id', () {
    expect(layout.pageById('credits'), isA<ConfigDocumentPage>());
    expect(layout.pageById('nope'), isNull);
  });

  test('an info page sizes and places its rows', () {
    final info = layout.pageById('info')! as ConfigInfoPage;

    expect(info.rowCount(3), 4);
    expect(info.visualIndex(1, 3), 3);
  });
}
