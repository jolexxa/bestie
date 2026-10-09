import 'package:bestie_platform_abstractions/bestie_platform_abstractions.dart'
    show ProgramCommand;
import 'package:intentions/intentions.dart';

/// How to start a server for one bestie directory.
@model
final class LocalServerLaunch {
  const LocalServerLaunch({
    required this.command,
    required this.bestieDir,
    required this.logFile,
  });

  final ProgramCommand command;

  /// The directory holding the model index and the lock file.
  final String bestieDir;

  /// Where the server appends its log.
  final String logFile;

  /// The full argument list for the server.
  List<String> get arguments => [
    ...command.arguments,
    '--bestie-dir',
    bestieDir,
    '--log',
    logFile,
  ];
}
