import 'package:bestie_config_use_case/src/config_use_case.dart';
import 'package:config_repository/config_repository.dart';
import 'package:intentions/intentions.dart';

@PartOf(ConfigUseCase)
final class ConfigSession implements ConfigView {
  ConfigSession(this._repo);

  final ConfigRepository _repo;
  final ConfigEdits _edits = {};

  ConfigView get _view => _repo.view(edits: _edits);

  ConfigEdits get edits => Map.unmodifiable(_edits);

  void update<T>(ConfigAddress<T> address, ConfigEdit<T> edit) {
    updateBase(address, edit);
  }

  void updateBase(ConfigAddressBase address, ConfigEditBase edit) {
    _edits[address] = edit;
    if (address.key.effect == ConfigEffect.live) {
      _repo.applyLive({address: edit});
    }
  }

  void commit() {
    _repo.commit(edits);
    _edits.clear();
  }

  void discardStaged() => _edits.clear();

  @override
  Resolved<Object?> inspectBase(ConfigAddressBase address) =>
      _view.inspectBase(address);

  @override
  Resolved<T> inspect<T>(ConfigAddress<T> address) => _view.inspect(address);

  @override
  Object? resolveBase(ConfigAddressBase address) => _view.resolveBase(address);

  @override
  T resolve<T>(ConfigAddress<T> address) => _view.resolve(address);

  @override
  bool isExplicitBase(ConfigAddressBase address) =>
      _view.isExplicitBase(address);

  @override
  bool isExplicit<T>(ConfigAddress<T> address) => _view.isExplicit(address);

  @override
  bool definesBase(ConfigAddressBase address) => _view.definesBase(address);

  @override
  bool defines<T>(ConfigAddress<T> address) => _view.defines(address);
}
