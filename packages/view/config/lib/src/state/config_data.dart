import 'package:config_repository/config_repository.dart';
import 'package:intentions/intentions.dart';

@model
class ConfigData {
  ConfigData({required this.selectedPageId});

  /// Id of the currently selected `ConfigPage`.
  String selectedPageId;
  int selectedIndex = 0;
  String? editError;
  ConfigScope? targetScope;
  int toolCount = 0;
}
