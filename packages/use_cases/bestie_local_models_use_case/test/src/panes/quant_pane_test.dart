import 'dart:async';

import 'package:bestie_local_models_use_case/src/panes/quant_pane.dart';
import 'package:command_protocol/command_protocol.dart';
import 'package:local_models_repository/local_models_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

import '../../helpers/fixtures.dart';

void main() {
  final q4 = repoQuant();
  final q6 = repoQuant(
    label: 'Q6_K',
    type: QuantType.q6K,
    sizeBytes: 16 * gigabyte,
  );
  final bf16 = repoQuant(
    label: 'BF16',
    type: QuantType.bf16,
    sizeBytes: 23 * gigabyte,
  );
  final iq4 = repoQuant(label: 'IQ4_XS', type: QuantType.iq4ExtraSmall);
  final q8 = repoQuant(label: 'Q8_0', type: QuantType.q8Zero);
  final resolved = RepoResolved(
    repo: gemmaRepo.repo,
    architecture: 'gemma4',
    parameterCount: 7500000000,
    contextLength: 131072,
    quants: [q4, q6, bf16, iq4, q8],
  );

  late MockLocalModelsOperations operations;
  late StreamController<ModelLibrary> library;

  setUp(() {
    operations = MockLocalModelsOperations();
    library = StreamController<ModelLibrary>.broadcast();
    stubOperations(operations, library: library.stream);
  });

  QuantPane paneResolving(RepoResolution resolution) {
    when(
      () => operations.resolve(gemmaRepo.repo),
    ).thenAnswer((_) async => resolution);
    return QuantPane(operations: operations, repo: gemmaRepo);
  }

  Future<PaneContent> contentOnce(QuantPane pane, ModelLibrary shown) async {
    final contents = <PaneContent>[];
    final subscription = pane.content('').listen(contents.add);
    await pumpEventQueue();
    library.add(shown);
    await pumpEventQueue();
    await subscription.cancel();
    return contents.last;
  }

  test('is titled by the repo and has no filter', () {
    final pane = paneResolving(resolved);
    expect(pane.title, 'gemma-4-E4B-it-GGUF');
    expect(pane.filter, PaneFilter.none);
    expect(pane.backLabel, 'Back to results');
  });

  test('names the owner, then the repo, but not this machine', () async {
    final pane = paneResolving(resolved);
    final bands = await pane.status.toList();
    expect(bands.map((band) => spansText(band!.spans)), [
      'lmstudio-community',
      'lmstudio-community · gemma4 · 7.5B params · 128k context',
    ]);
  });

  test('keeps just the owner when the repo could not be read', () async {
    final pane = paneResolving(const RepoNotFound(repo: 'x/y'));
    final bands = await pane.status.toList();
    expect(bands.map((band) => spansText(band!.spans)), ['lmstudio-community']);
  });

  test('leaves out facts the repo does not give', () async {
    final pane = paneResolving(
      RepoResolved(repo: gemmaRepo.repo, quants: [q4]),
    );
    final bands = await pane.status.toList();
    expect(spansText(bands.last!.spans), 'lmstudio-community');
  });

  test('reads the repo once however often it is shown', () async {
    final pane = paneResolving(resolved);
    await pane.status.drain<void>();
    await contentOnce(pane, readyLibrary);
    await contentOnce(pane, readyLibrary);
    verify(() => operations.resolve(gemmaRepo.repo)).called(1);
  });

  test('says it is reading the repo until it is resolved', () async {
    final pending = Completer<RepoResolution>();
    when(
      () => operations.resolve(gemmaRepo.repo),
    ).thenAnswer((_) => pending.future);
    final pane = QuantPane(operations: operations, repo: gemmaRepo);
    final contents = <PaneContent>[];
    final subscription = pane.content('').listen(contents.add);
    await pumpEventQueue();
    expect(contents.single.rows, isEmpty);
    expect(contents.single.sections.single.notes.map(noteText), [
      '',
      '∷ Reading the repo and its GGUF files…',
      '  Checking which quants this machine can run',
    ]);
    await subscription.cancel();
    pending.complete(resolved);
    await pumpEventQueue();
    expect(library.hasListener, isFalse);
  });

  group('a quant row', () {
    test('is one line: quant, size, quality, fit and a bar', () async {
      final content = await contentOnce(paneResolving(resolved), readyLibrary);
      final section = content.sections.single;
      expect(section.columns.map((column) => column.title), [
        'Quant',
        'Size',
        'Quality',
        'Fit',
        '',
      ]);
      final row = section.rows.first;
      expect(row.label, 'Q4_K_M');
      expect(row.detail, isEmpty);
      expect(row.cells.map(spansText), [
        '4.97 GB',
        'great',
        'fits',
        '━━━━${'─' * 14}',
      ]);
      expect(row.cells[1].single.tone, PaneTone.success);
      expect(row.cells[3].first.tone, PaneTone.success);
    });

    test('judges the fit against this machine and fills the bar', () async {
      final content = await contentOnce(paneResolving(resolved), readyLibrary);
      expect(rowById(content, q6.downloadId).cells.skip(2).map(spansText), [
        'tight',
        '${'━' * 14}────',
      ]);
      expect(rowById(content, bf16.downloadId).cells.skip(2).map(spansText), [
        'too big',
        '━' * 18,
      ]);
    });

    test('never draws a quant so small its bar is empty', () async {
      final tiny = repoQuant(
        label: 'Q8_0',
        type: QuantType.q8Zero,
        sizeBytes: 639000000,
      );
      final content = await contentOnce(
        paneResolving(
          RepoResolved(
            repo: gemmaRepo.repo,
            architecture: 'qwen3',
            parameterCount: 596000000,
            contextLength: 40960,
            quants: [tiny],
          ),
        ),
        readyLibrary,
      );
      expect(
        spansText(rowById(content, tiny.downloadId).cells.last),
        '━${'─' * 17}',
      );
    });

    test('downloads on Enter and stays', () async {
      when(
        () => operations.download(q4),
      ).thenAnswer((_) async => DownloadAccepted(q4.downloadId));
      final content = await contentOnce(paneResolving(resolved), readyLibrary);
      final action = actionOf(
        rowById(content, q4.downloadId),
        const PrimaryKey(),
      );
      expect(action.label, 'Download');
      expect(await action.invoke(), isA<PaneStay>());
      verify(() => operations.download(q4)).called(1);
    });

    test('mutes a quant the library has, with no download', () async {
      final content = await contentOnce(
        paneResolving(resolved),
        ModelLibrary(
          downloaded: [
            supportedModel(
              source: DownloadedSource(
                downloadId: iq4.downloadId,
                repo: gemmaRepo.repo,
                file: 'x',
              ),
            ),
            unsupportedModel(),
          ],
          downloading: [modelDownload(id: q8.downloadId)],
          needsAttention: [modelDownload(id: q6.downloadId)],
        ),
      );
      final installed = rowById(content, iq4.downloadId);
      expect(installed.labelTone, PaneTone.muted);
      expect(installed.cells.map(spansText).take(3), [
        '4.97 GB',
        'good',
        'installed',
      ]);
      expect(installed.cells.first.single.tone, PaneTone.muted);
      expect(installed.cells[3].first.tone, PaneTone.muted);
      expect(installed.actions, isEmpty);
      expect(spansText(rowById(content, q8.downloadId).cells[2]), 'queued');
      expect(spansText(rowById(content, q6.downloadId).cells[2]), 'queued');
      expect(rowById(content, q4.downloadId).actions, hasLength(1));
    });

    Future<PaneActionResult> downloading(DownloadRequestResult result) async {
      when(() => operations.download(q4)).thenAnswer((_) async => result);
      final content = await contentOnce(paneResolving(resolved), readyLibrary);
      return actionOf(
        rowById(content, q4.downloadId),
        const PrimaryKey(),
      ).invoke();
    }

    test('stays when the quant is already queued', () async {
      expect(
        await downloading(const DownloadAlreadyQueued('d')),
        isA<PaneStay>(),
      );
    });

    test('says why the download was refused', () async {
      Future<String> reasonFor(DownloadRequestResult result) async =>
          (await downloading(result) as PaneRejected).reason;

      expect(
        await reasonFor(
          const DownloadTargetOccupied(
            'd',
            path: '$homeDir/.bestie/models/x.gguf',
          ),
        ),
        "A file bestie didn't download is already at ~/.bestie/models/x.gguf",
      );
      expect(
        await reasonFor(
          const DownloadRejected('d', reason: InvalidRepoId('bad')),
        ),
        'bad is not a repo bestie can fetch',
      );
      expect(
        await reasonFor(
          const DownloadRejected('d', reason: InvalidFilePath('../x')),
        ),
        '../x would land outside the repo',
      );
      expect(
        await reasonFor(const DownloadRejected('d', reason: NoDownloadFiles())),
        'This quant has no files to download',
      );
      when(() => operations.currentLibrary).thenReturn(
        const ModelLibrary(downloadsStatus: DownloadsManagedElsewhere()),
      );
      expect(
        await reasonFor(const DownloadsUnavailable('d')),
        'Another bestie window runs downloads; use that one',
      );
    });
  });

  group('when nothing can be listed', () {
    Future<List<String>> notesFor(RepoResolution resolution) async {
      final content = await contentOnce(
        paneResolving(resolution),
        readyLibrary,
      );
      expect(content.rows, isEmpty);
      return content.sections.single.notes.map(noteText).toList();
    }

    test('says the repo does not exist', () async {
      expect(await notesFor(const RepoNotFound(repo: 'a/b')), [
        '',
        "✕ Hugging Face has no repo called a/b, or it's private.",
      ]);
    });

    test('says the lookup failed and why', () async {
      expect(
        await notesFor(
          const RepoLookupFailed(repo: 'a/b', message: 'HTTP 500'),
        ),
        ['', "✕ Couldn't read the repo from Hugging Face.", '', '  HTTP 500'],
      );
    });

    test('says there is nothing bestie can run and why', () async {
      expect(
        await notesFor(
          const RepoUnrunnable(
            repo: 'a/b',
            reason: ArchitectureUnsupported('gemma4v'),
          ),
        ),
        [
          '',
          "✕ There's nothing in this repo bestie can run yet.",
          '',
          "  Architecture gemma4v isn't supported. Bestie runs",
          '  qwen2/3/3.5, gpt-oss, gemma4 and glm4 models today.',
        ],
      );
    });
  });
}
