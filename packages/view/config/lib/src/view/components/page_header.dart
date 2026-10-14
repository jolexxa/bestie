import 'package:bestie_ui/bestie_ui.dart';
import 'package:intentions/intentions.dart';
import 'package:nocterm/nocterm.dart';

/// Per-page title header inside the right pane.
@view
class PageHeader extends StatelessComponent {
  const PageHeader({required this.title, super.key});

  /// Page name, drawn in primary color (e.g. `'Model'`).
  final String title;

  @override
  Component build(BuildContext context) {
    final theme = AppTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 1),
        Container(
          height: 1,
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Text(
            title,
            style: TextStyle(color: theme.primary, fontWeight: FontWeight.bold),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 2),
          child: Divider(),
        ),
        const SizedBox(height: 1),
      ],
    );
  }
}
