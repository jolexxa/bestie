import 'package:bestie_mascot_use_case/src/mascot.dart';
import 'package:bestie_mascot_use_case/src/mascot_config_keys.dart';
import 'package:config_repository/config_repository.dart';
import 'package:intentions/intentions.dart';

/// Owns which mascot greets from the corner of the app; the view subscribes.
@useCase
class MascotUseCase {
  MascotUseCase({
    required ConfigRepository config,
    required MascotConfigKeys configKeys,
  }) : _config = config,
       _configKeys = configKeys;

  final ConfigRepository _config;
  final MascotConfigKeys _configKeys;

  /// The currently selected mascot.
  Mascot get mascot => Mascot.parse(_config.resolve(_configKeys.mascot.global));

  /// Emits the selected mascot on every change.
  Stream<Mascot> get mascotChanges =>
      _config.watch(_configKeys.mascot.global).map(Mascot.parse);
}
