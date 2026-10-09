import 'dart:async';

import 'package:bestie_local_models_use_case/src/local_models_operations.dart';
import 'package:bestie_local_models_use_case/src/local_models_use_case.dart';
import 'package:bestie_local_models_use_case/src/panes/quant_pane.dart';
import 'package:bestie_local_models_use_case/src/support/latest_throttle.dart';
import 'package:bestie_local_models_use_case/src/wording/library_wording.dart';
import 'package:bestie_local_models_use_case/src/wording/units.dart';
import 'package:command_protocol/command_protocol.dart';
import 'package:intentions/intentions.dart';
import 'package:local_models_repository/local_models_repository.dart';
import 'package:rxdart/rxdart.dart';

/// Searches Hugging Face for GGUF repos as the user types; the most
/// downloaded ones while the query is empty. Enter opens a repo's quants.
@PartOf(LocalModelsUseCase)
class DownloadPane extends Pane {
  DownloadPane({
    required LocalModelsOperations operations,
    required StartTimer startTimer,
    this.debounce = const Duration(milliseconds: 350),
  }) : _operations = operations,
       _startTimer = startTimer;

  final LocalModelsOperations _operations;
  final StartTimer _startTimer;

  /// How long typing must pause before a search goes out.
  final Duration debounce;

  final _status = BehaviorSubject<PaneStatus?>.seeded(null);
  SearchedRepos? _last;

  @override
  String get title => 'Download';

  @override
  String get placeholder => 'Search Hugging Face for GGUF models…';

  @override
  PaneFilter get filter => PaneFilter.search;

  @override
  Stream<PaneStatus?> get status => _status.stream;

  @override
  Stream<PaneContent> content(String query) =>
      Stream<PaneContent>.multi((controller) {
        StreamSubscription<PaneContent>? listing;
        var cancelled = false;
        void show(SearchedRepos searched) {
          _status.add(_statusOf(searched));
          listing = _operations.library
              .map((library) => _contentOf(searched, library))
              .listen(controller.add);
        }

        Future<void> searchNow() async {
          _status.add(query.trim().isEmpty ? null : _searching);
          final searched = SearchedRepos(
            query: query,
            result: await _searchFor(query),
          );
          if (cancelled) return;
          if (searched.result is RepoSearchSucceeded) _last = searched;
          show(searched);
        }

        final cached = _last;
        final timer = cached != null && cached.query == query
            ? null
            : _startTimer(query.trim().isEmpty ? Duration.zero : debounce, () {
                unawaited(searchNow());
              });
        if (timer == null) show(cached!);
        controller.onCancel = () {
          cancelled = true;
          timer?.cancel();
          return listing?.cancel();
        };
      });

  /// What searching for [query] found; a search that breaks counts as
  /// failed, so the band never keeps saying it is searching.
  Future<RepoSearchResult> _searchFor(String query) async {
    try {
      return await _operations.search(query);
    } on Object catch (error) {
      return RepoSearchFailed('$error');
    }
  }

  static const _searching = PaneStatus(
    spans: [PaneSpan('Searching Hugging Face', PaneTone.muted)],
    progress: PaneIndeterminate(),
  );

  static PaneStatus? _statusOf(SearchedRepos searched) =>
      switch (searched.result) {
        RepoSearchSucceeded() when searched.query.trim().isEmpty => null,
        RepoSearchSucceeded(:final repos) => PaneStatus(
          spans: const [],
          trailing: [
            PaneSpan(
              repos.length == 1 ? '1 result' : '${repos.length} results',
              PaneTone.muted,
            ),
          ],
        ),
        RepoSearchFailed(:final message) => _problem(
          "Hugging Face couldn't search: $message",
        ),
        RepoSearchTimedOut(:final timeout) => _problem(
          "Hugging Face didn't answer within ${timeout.inSeconds}s. Check "
          'your connection, then type to retry.',
        ),
      };

  static PaneStatus _problem(String text) => PaneStatus(
    glyph: '⚠',
    glyphTone: PaneTone.danger,
    spans: [PaneSpan(text, PaneTone.danger)],
  );

  PaneContent _contentOf(SearchedRepos searched, ModelLibrary library) =>
      switch (searched.result) {
        RepoSearchSucceeded(:final repos) when repos.isNotEmpty => PaneContent([
          PaneSection(
            title: searched.query.trim().isEmpty
                ? 'Most downloaded GGUFs'
                : 'Hugging Face',
            rows: [
              for (final repo in repos)
                _rowOf(repo, have: _reposIn(library).contains(repo.repo)),
            ],
          ),
        ]),
        RepoSearchSucceeded() => PaneContent([
          PaneSection(
            rows: const [],
            notes: [
              const PaneNote.blank(),
              PaneNote([
                PaneSpan(
                  'No GGUF repos match “${searched.query.trim()}”.',
                  PaneTone.muted,
                ),
              ]),
              const PaneNote.blank(),
              const PaneNote([
                PaneSpan(
                  'Try a family name like qwen3, gemma 4 or gpt-oss.',
                  PaneTone.muted,
                ),
              ]),
            ],
          ),
        ]),
        RepoSearchFailed() || RepoSearchTimedOut() => const PaneContent.empty(),
      };

  /// Repos the library already has a quant of, downloaded or on its way.
  static Set<String> _reposIn(ModelLibrary library) => {
    for (final download in [
      ...library.downloading,
      ...library.needsAttention,
    ])
      download.repo,
    for (final model in library.downloaded)
      if (model.source case DownloadedSource(:final repo)) repo,
  };

  PaneRow _rowOf(RepoSummary repo, {required bool have}) {
    final unrunnable = repo.unrunnable;
    return PaneRow(
      id: repo.repo,
      glyph: switch (unrunnable) {
        _ when have => '✓',
        null => '·',
        _ => '⊘',
      },
      glyphTone: have ? PaneTone.success : PaneTone.muted,
      label: repo.name,
      labelTone: unrunnable == null ? PaneTone.plain : PaneTone.muted,
      keywords: repo.repo,
      trailing: [PaneSpan(_statsOf(repo), PaneTone.muted)],
      detail: [
        PaneSpan(repo.owner, PaneTone.muted),
        if (unrunnable != null) ...[
          const PaneSpan(' · ', PaneTone.subtle),
          PaneSpan(unrunnableLabel(unrunnable), PaneTone.warning),
        ] else if (_factsOf(repo) case final String facts) ...[
          const PaneSpan(' · ', PaneTone.subtle),
          PaneSpan(facts, PaneTone.info),
        ],
      ],
      actions: [
        PaneAction.primary(
          label: unrunnable == null ? 'Choose quant' : 'Why',
          invoke: () async => PanePush(
            QuantPane(operations: _operations, repo: repo),
          ),
        ),
      ],
    );
  }

  static String _statsOf(RepoSummary repo) => [
    if (repo.downloads case final downloads?) '↓${countLabel(downloads)}',
    if (repo.likes case final likes?) '♡${countLabel(likes)}',
  ].join('  ');

  static String? _factsOf(RepoSummary repo) {
    final facts = [
      ?repo.architecture,
      if (repo.parameterCount case final count?) parametersLabel(count),
    ];
    return facts.isEmpty ? null : facts.join(' · ');
  }

  Future<void> dispose() => _status.close();
}

/// A query and what searching for it found.
@model
final class SearchedRepos {
  const SearchedRepos({required this.query, required this.result});

  final String query;

  final RepoSearchResult result;
}
