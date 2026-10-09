import 'package:args/args.dart';
import 'package:intentions/intentions.dart';
import 'package:path/path.dart' as p;

/// How the server was asked to run.
@model
final class ServerArguments {
  const ServerArguments({required this.bestieDir, this.logPath});

  final String bestieDir;

  /// The file to append the log to, or null to log to stderr.
  final String? logPath;

  static final _parser = ArgParser()
    ..addOption(
      'bestie-dir',
      help: 'The bestie directory holding models/ and run/.',
      valueHelp: 'path',
    )
    ..addOption('log', help: 'Append the log to this file.', valueHelp: 'path')
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show this help.');

  static String get usage => _parser.usage;

  /// Reads [arguments], defaulting the bestie directory to `.bestie` under
  /// [home].
  static ServerArgumentsParse parse(
    List<String> arguments, {
    required String home,
  }) {
    final ArgResults results;
    try {
      results = _parser.parse(arguments);
    } on FormatException catch (error) {
      return ServerArgumentsInvalid(error.message);
    }
    if (results.flag('help')) return const ServerArgumentsHelp();
    return ServerArgumentsParsed(
      ServerArguments(
        bestieDir: results.option('bestie-dir') ?? p.join(home, '.bestie'),
        logPath: results.option('log'),
      ),
    );
  }
}

@model
sealed class ServerArgumentsParse {
  const ServerArgumentsParse();
}

@model
final class ServerArgumentsParsed extends ServerArgumentsParse {
  const ServerArgumentsParsed(this.arguments);

  final ServerArguments arguments;
}

@model
final class ServerArgumentsHelp extends ServerArgumentsParse {
  const ServerArgumentsHelp();
}

@model
final class ServerArgumentsInvalid extends ServerArgumentsParse {
  const ServerArgumentsInvalid(this.message);

  final String message;
}
