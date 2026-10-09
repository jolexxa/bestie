import 'dart:async';

import 'package:bestie_commands_use_case/bestie_commands_use_case.dart';
import 'package:command_protocol/command_protocol.dart';

final class FakeContribution implements CommandContribution {
  FakeContribution(this.commands);

  @override
  final List<Command> commands;
}

CommandsUseCase catalogOf(List<Command> commands) =>
    CommandsUseCase(contributions: [FakeContribution(commands)]);

Command simpleCommand(
  String id, {
  String? title,
  String group = 'Test',
  String description = '',
  CommandTier tier = CommandTier.normal,
  String? glyph,
  String? shortcut,
  String? running,
  Stream<Availability>? availability,
  Stream<CommandStatus?>? status,
  Future<CommandResult> Function(Answers answers)? invoke,
  Param? Function(Answers soFar)? next,
  Pane? pane,
}) => Command(
  id: id,
  title: title ?? id,
  description: description,
  tier: tier,
  glyph: glyph,
  shortcut: shortcut,
  group: group,
  availability: availability ?? const Stream.empty(),
  status: status ?? const Stream.empty(),
  body: pane == null
      ? CommandFlow(
          invoke: invoke ?? (_) async => const CommandRan(),
          next: next ?? CommandFlow.noParams,
          running: running,
        )
      : CommandPane(pane),
);

/// A pane whose content and status the test drives by hand.
final class DemoPane extends Pane {
  DemoPane({
    this.title = 'Demo',
    this.filter = PaneFilter.fuzzy,
    this.placeholder,
    this.backLabel = 'Back',
  });

  @override
  final String title;

  @override
  final String backLabel;

  @override
  final PaneFilter filter;

  @override
  final String? placeholder;

  final _content = StreamController<PaneContent>.broadcast();
  final _status = StreamController<PaneStatus?>.broadcast();

  /// Every query the palette asked for, in order.
  final List<String> queries = [];

  bool get watched => _content.hasListener;

  bool get statusWatched => _status.hasListener;

  @override
  Stream<PaneContent> content(String query) {
    queries.add(query);
    return _content.stream;
  }

  @override
  Stream<PaneStatus?> get status => _status.stream;

  void show(PaneContent content) => _content.add(content);

  void report(PaneStatus? status) => _status.add(status);

  void failContent(Object error) => _content.addError(error);

  void failStatus(Object error) => _status.addError(error);

  Future<void> close() async {
    await _content.close();
    await _status.close();
  }
}

/// An action that records each run and settles with [result].
PaneAction demoAction(
  List<String> runs,
  String name, {
  PaneKey key = const PrimaryKey(),
  PaneActionResult result = const PaneStay(),
  bool danger = false,
}) => PaneAction(
  key: key,
  label: name,
  danger: danger,
  invoke: () async {
    runs.add(name);
    return result;
  },
);
