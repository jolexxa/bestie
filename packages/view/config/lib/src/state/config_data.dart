import 'package:intentions/intentions.dart';

@model
class ConfigData {
  ConfigData({required this.selectedPageId});

  /// Id of the currently selected `ConfigPage`.
  String selectedPageId;
  int selectedIndex = 0;
  String? editError;
  int toolCount = 0;
}
