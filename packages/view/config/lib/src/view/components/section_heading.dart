import 'package:bestie_ui/bestie_ui.dart';
import 'package:intentions/intentions.dart';
import 'package:nocterm/nocterm.dart';

/// Inline sub-section heading rendered between groups of config rows.
///
/// Layout (4 rows): top spacer / CAPS label in primary / soft divider /
/// bottom spacer. The top spacer can be suppressed when this heading
/// sits directly beneath a page header.
@view
class SectionHeading extends StatelessComponent {
  const SectionHeading({
    required this.label,
    this.suppressTopSpacer = false,
    super.key,
  });

  /// Display label, drawn upper-cased in primary color.
  final String label;

  /// When true, omits the leading 1-row spacer. Use when this heading
  /// is the first thing under a page header that already provides padding.
  final bool suppressTopSpacer;

  @override
  Component build(BuildContext context) {
    final theme = AppTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!suppressTopSpacer) const SizedBox(height: 1),
        Container(
          height: 1,
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              color: theme.primary,
              fontWeight: FontWeight.bold,
            ),
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
