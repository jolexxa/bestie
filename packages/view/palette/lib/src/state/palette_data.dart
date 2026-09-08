import 'package:command_protocol/command_protocol.dart';
import 'package:intentions/intentions.dart';

/// Shared mutable state for the palette state machine.
@model
final class PaletteData {
  PaletteData({required this.catalog});

  /// Every command the palette can offer, in contribution order.
  final List<Command> catalog;

  /// Latest availability observed per command id; absent means available.
  final Map<String, Availability> availability = {};

  String query = '';
  int selectedIndex = 0;

  /// Rejection reason from the last invocation, surfaced while browsing.
  String? error;

  Command? active;
  Param? currentParam;
  Answers answers = const Answers.empty();
  List<Option<Object?>> options = const [];
  String optionQuery = '';
  final Set<int> toggled = {};

  /// Validation problem for the value currently being collected.
  String? editError;

  void resetBrowse() {
    query = '';
    selectedIndex = 0;
    error = null;
  }

  void beginFlow(Command command) {
    active = command;
    answers = const Answers.empty();
    error = null;
  }

  void prepareParam(Param param) {
    currentParam = param;
    options = const [];
    optionQuery = '';
    toggled.clear();
    selectedIndex = 0;
    editError = null;
  }

  void endFlow() {
    active = null;
    currentParam = null;
    answers = const Answers.empty();
    options = const [];
    optionQuery = '';
    toggled.clear();
    editError = null;
  }
}
