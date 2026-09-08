import 'package:bestie_edit/bestie_edit.dart';
import 'package:edit_data_source/edit_data_source.dart';
import 'package:fs_tools/fs_tools.dart';
import 'package:mocktail/mocktail.dart';
import 'package:process_host/process_host.dart';
import 'package:test/test.dart';
import 'package:tool_protocol/tool_protocol.dart';

class _MockEditDataSource extends Mock implements EditDataSource {}

class _FakeSandbox implements Sandbox {}

const _diff = FileDiff(hunks: [], added: 1, removed: 1);

const _notStarted = EditProgramNotStarted(
  SpawnFailure(function: 'posix_spawnp', message: 'not found'),
);

void main() {
  setUpAll(() {
    registerFallbackValue(
      const ReplaceRequest(path: '', oldText: '', newText: ''),
    );
    registerFallbackValue(_FakeSandbox());
  });

  late _MockEditDataSource editor;
  late FsTools tools;

  setUp(() {
    editor = _MockEditDataSource();
    tools = FsTools(editor: editor);
  });

  void whenEditorRuns(EditRun run) => when(
    () => editor.edit(any(), sandbox: any(named: 'sandbox')),
  ).thenAnswer((_) async => run);

  group('editFile', () {
    Future<EditFileOutcome> edit({bool replaceAll = false, Sandbox? sandbox}) =>
        tools.editFile(
          path: '/work/a.dart',
          oldText: 'old',
          newText: 'new',
          replaceAll: replaceAll,
          sandbox: sandbox,
        );

    test('hands the request and sandbox down as they were given', () async {
      final sandbox = _FakeSandbox();
      whenEditorRuns(const EditAnswered(EditNoChange()));

      await edit(replaceAll: true, sandbox: sandbox);

      verify(
        () => editor.edit(
          const ReplaceRequest(
            path: '/work/a.dart',
            oldText: 'old',
            newText: 'new',
            replaceAll: true,
          ),
          sandbox: sandbox,
        ),
      ).called(1);
    });

    test('carries a success through with what the editor said', () async {
      whenEditorRuns(
        const EditAnswered(
          EditSucceeded(replacements: 2, snippet: '     1\tnew', diff: _diff),
        ),
      );

      final outcome = await edit() as EditFileSucceeded;

      expect(outcome.path, '/work/a.dart');
      expect(outcome.replacements, 2);
      expect(outcome.snippet, '     1\tnew');
      expect(outcome.diff, _diff);
    });

    test('names the file on every refusal', () async {
      final refusals = <EditReply, Type>{
        const EditTargetMissing(): EditFileTargetMissing,
        const EditAmbiguous(occurrences: 3): EditFileAmbiguous,
        const EditNoChange(): EditFileNoChange,
        const EditPathMissing(): EditFilePathMissing,
        const EditIsDirectory(): EditFileIsDirectory,
        const EditDenied(): EditFileDenied,
        const EditNotText(): EditFileNotText,
      };
      for (final MapEntry(key: reply, value: expected) in refusals.entries) {
        whenEditorRuns(EditAnswered(reply));

        final outcome = await edit();

        expect(outcome.runtimeType, expected);
        expect(outcome.path, '/work/a.dart');
      }
    });

    test('counts the occurrences an ambiguous edit found', () async {
      whenEditorRuns(const EditAnswered(EditAmbiguous(occurrences: 3)));

      expect((await edit() as EditFileAmbiguous).occurrences, 3);
    });

    test('treats an answer meant for a create as an editor fault', () async {
      for (final reply in const [EditCreated(), EditPathExists()]) {
        whenEditorRuns(EditAnswered(reply));

        final outcome = await edit() as EditFileEditorFailed;

        expect(outcome.reason, contains('out of turn'));
      }
    });

    test('explains an editor that never started', () async {
      whenEditorRuns(_notStarted);

      final outcome = await edit() as EditFileEditorFailed;

      expect(outcome.reason, contains('not found'));
    });

    test('repeats what a failed editor said on stderr', () async {
      whenEditorRuns(
        const EditProgramFailed(exit: ProcessExited(2), stderr: 'disk full'),
      );

      expect((await edit() as EditFileEditorFailed).reason, 'disk full');
    });

    test('names the exit when a failed editor said nothing', () async {
      whenEditorRuns(
        const EditProgramFailed(exit: ProcessSignaled(9), stderr: ''),
      );

      expect(
        (await edit() as EditFileEditorFailed).reason,
        contains('ProcessSignaled(9)'),
      );
    });

    test('explains an unreadable answer', () async {
      whenEditorRuns(const EditProgramGarbled('???'));

      expect(
        (await edit() as EditFileEditorFailed).reason,
        contains('unreadable'),
      );
    });
  });

  group('createFile', () {
    Future<CreateFileOutcome> create({Sandbox? sandbox}) => tools.createFile(
      path: '/work/new.dart',
      contents: 'void main() {}\n',
      sandbox: sandbox,
    );

    test('hands the request and sandbox down as they were given', () async {
      final sandbox = _FakeSandbox();
      whenEditorRuns(const EditAnswered(EditCreated()));

      await create(sandbox: sandbox);

      verify(
        () => editor.edit(
          const CreateRequest(
            path: '/work/new.dart',
            contents: 'void main() {}\n',
          ),
          sandbox: sandbox,
        ),
      ).called(1);
    });

    test('names the file on every answer', () async {
      final answers = <EditReply, Type>{
        const EditCreated(): CreateFileSucceeded,
        const EditPathExists(): CreateFilePathExists,
        const EditIsDirectory(): CreateFilePathExists,
        const EditDenied(): CreateFileDenied,
      };
      for (final MapEntry(key: reply, value: expected) in answers.entries) {
        whenEditorRuns(EditAnswered(reply));

        final outcome = await create();

        expect(outcome.runtimeType, expected);
        expect(outcome.path, '/work/new.dart');
      }
    });

    test('treats an answer meant for an edit as an editor fault', () async {
      const strays = [
        EditSucceeded(replacements: 1, snippet: '', diff: _diff),
        EditTargetMissing(),
        EditAmbiguous(occurrences: 2),
        EditNoChange(),
        EditPathMissing(),
        EditNotText(),
      ];
      for (final reply in strays) {
        whenEditorRuns(EditAnswered(reply));

        final outcome = await create() as CreateFileEditorFailed;

        expect(outcome.reason, contains('out of turn'), reason: '$reply');
      }
    });

    test('explains an editor that never answered', () async {
      whenEditorRuns(_notStarted);

      final outcome = await create() as CreateFileEditorFailed;

      expect(outcome.reason, contains('not found'));
    });
  });
}
