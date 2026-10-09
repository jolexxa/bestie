import 'package:intentions/intentions.dart';
import 'package:local_models_repository/src/local_models_repository.dart';
import 'package:local_models_repository/src/scan/model_scanner.dart';
import 'package:local_models_repository/src/scan/scan_input.dart';
import 'package:local_models_repository/src/scan/scan_output.dart';
import 'package:logic_blocks/logic_blocks.dart';

/// The folders the next scan walks.
@model
final class ScanRoots {
  List<String> value = const [];
}

/// Whether the library is being scanned. Requests that arrive mid-scan fold
/// into one more scan once it finishes, so a burst of changes costs at most
/// two walks and the last one always sees the latest roots.
@PartOf(LocalModelsRepository)
sealed class ScanState extends StateLogic<ScanState> {
  ScanRoots get roots => get<ScanRoots>();

  ModelScanner get scanner => get<ModelScanner>();

  bool get scanning => true;

  Transition aimAt(RescanRequested input, Transition next) {
    roots.value = input.roots;
    return next;
  }
}

@PartOf(LocalModelsRepository)
final class ScanIdleState extends ScanState {
  ScanIdleState() {
    on<RescanRequested>((input) => aimAt(input, to<ScanRunningState>()));
  }

  @override
  bool get scanning => false;
}

@PartOf(LocalModelsRepository)
final class ScanRunningState extends ScanState {
  ScanRunningState() {
    onEnter(() {
      async(
        scanner.scan(roots.value),
      ).input(ScanFinished.new).errorInput(ScanThrew.new);
    });

    on<RescanRequested>((input) => aimAt(input, to<ScanStaleState>()));
    on<ScanFinished>((input) {
      output(ScanPublished(input.models));
      return to<ScanIdleState>();
    });
    on<ScanThrew>((input) {
      output(ScanFailed('${input.error}'));
      return to<ScanIdleState>();
    });
  }
}

/// A scan is under way, but asked for before the latest request; what it
/// finds is dropped and the walk starts over.
@PartOf(LocalModelsRepository)
final class ScanStaleState extends ScanState {
  ScanStaleState() {
    on<RescanRequested>((input) => aimAt(input, toSelf()));
    on<ScanFinished>((_) => to<ScanRunningState>());
    on<ScanThrew>((_) => to<ScanRunningState>());
  }
}

@PartOf(LocalModelsRepository)
final class ScanLogic extends LogicBlock<ScanState> {
  ScanLogic(ModelScanner scanner) {
    set(ScanRoots());
    set(scanner);

    set(ScanIdleState());
    set(ScanRunningState());
    set(ScanStaleState());
  }

  @override
  Transition getInitialState() => to<ScanIdleState>();
}
