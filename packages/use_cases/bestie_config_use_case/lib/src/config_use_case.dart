import 'package:bestie_config_use_case/src/config_session.dart';
import 'package:config_repository/config_repository.dart';
import 'package:intentions/intentions.dart';

@useCase
class ConfigUseCase implements ConfigView {
  ConfigUseCase(this._repo);

  final ConfigRepository _repo;
  ConfigSession? _session;

  ConfigView get _activeView => _session ?? _repo;

  void beginSession() => _session ??= ConfigSession(_repo);

  void endSession() {
    _session?.commit();
    _session = null;
  }

  void cancelSession() {
    _session?.discardStaged();
    _session = null;
  }

  @override
  Object? resolveBase(ConfigAddressBase address) =>
      _activeView.resolveBase(address);

  @override
  T resolve<T>(ConfigAddress<T> address) => _activeView.resolve(address);

  @override
  Resolved<Object?> inspectBase(ConfigAddressBase address) =>
      _activeView.inspectBase(address);

  @override
  Resolved<T> inspect<T>(ConfigAddress<T> address) =>
      _activeView.inspect(address);

  @override
  bool isExplicitBase(ConfigAddressBase address) =>
      _activeView.isExplicitBase(address);

  @override
  bool isExplicit<T>(ConfigAddress<T> address) =>
      _activeView.isExplicit(address);

  @override
  bool definesBase(ConfigAddressBase address) =>
      _activeView.definesBase(address);

  @override
  bool defines<T>(ConfigAddress<T> address) => _activeView.defines(address);

  void update<T>(ConfigAddress<T> address, ConfigEdit<T> edit) {
    updateBase(address, edit);
  }

  void updateBase(ConfigAddressBase address, ConfigEditBase edit) {
    final session = _session;
    if (session == null) {
      _repo.commit({address: edit});
      return;
    }
    session.updateBase(address, edit);
  }

  Stream<ConfigChange> get changes => _repo.changes;

  Stream<T> watch<T>(ConfigAddress<T> address) => _repo.watch(address);

  Future<void> dispose() => _repo.dispose();
}
