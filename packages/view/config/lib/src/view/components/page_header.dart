import 'package:bestie_ui/bestie_ui.dart';
import 'package:intentions/intentions.dart';
import 'package:nocterm/nocterm.dart';

/// Per-page title header inside the right pane.
///
/// Layout (4 rows): top spacer / title + optional muted scope / soft
/// divider / bottom spacer.
@view
class PageHeader extends StatelessComponent {
  const PageHeader({
    required this.title,
    this.scope,
    this.scopeWarning = false,
    super.key,
  });

  /// Page name, drawn in primary color (e.g. `'Model'`).
  final String title;

  /// Optional subtitle shown after a `·` separator in muted color (or
  /// warning color when [scopeWarning] is true). Use for per-page context
  /// like the current model id.
  final String? scope;

  /// When true, the [scope] is drawn in [AppThemeData.warning] instead of
  /// [AppThemeData.muted]. Useful for "no model" states.
  final bool scopeWarning;

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
          child: Row(
            children: [
              Text(
                title,
                style: TextStyle(
                  color: theme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (scope != null)
                Text(
                  ' · ${scope!}',
                  style: TextStyle(
                    color: scopeWarning ? theme.warning : theme.muted,
                  ),
                ),
            ],
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
