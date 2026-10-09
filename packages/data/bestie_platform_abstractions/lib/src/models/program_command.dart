import 'package:intentions/intentions.dart';
import 'package:meta/meta.dart';

/// How to start a program bestie ships: the executable, plus the arguments
/// that come before the program's own.
@model
@immutable
final class ProgramCommand {
  const ProgramCommand({required this.executable, this.arguments = const []});

  final String executable;

  final List<String> arguments;

  @override
  bool operator ==(Object other) =>
      other is ProgramCommand &&
      other.executable == executable &&
      _sameArguments(other.arguments);

  bool _sameArguments(List<String> other) {
    if (other.length != arguments.length) return false;
    for (var index = 0; index < arguments.length; index++) {
      if (other[index] != arguments[index]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(executable, Object.hashAll(arguments));

  @override
  String toString() => [executable, ...arguments].join(' ');
}
