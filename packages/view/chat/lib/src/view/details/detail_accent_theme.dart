import 'package:bestie_chat_view/src/view/details/item_details.dart';
import 'package:bestie_ui/bestie_ui.dart';
import 'package:nocterm/nocterm.dart';

/// Resolves a [DetailAccent] against the theme — the single place meaning
/// becomes color, so the chat stub and details header cannot drift apart.
extension DetailAccentTheme on DetailAccent {
  Color resolve(AppThemeData theme) => switch (this) {
    DetailAccent.normal => theme.onBackground,
    DetailAccent.muted => theme.muted,
    DetailAccent.error => theme.error,
    DetailAccent.success => theme.success,
    DetailAccent.running => theme.info,
    DetailAccent.emphasis => theme.highVisibility,
  };
}
