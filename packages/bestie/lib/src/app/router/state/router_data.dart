import 'package:bestie_ui/bestie_ui.dart' show AppMode;
import 'package:intentions/intentions.dart';

@model
class RouterData {
  AppMode mode = AppMode.chat;
  bool configOpen = false;
  bool paletteOpen = false;
}
