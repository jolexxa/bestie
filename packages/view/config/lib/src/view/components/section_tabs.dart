import 'package:bestie_config_use_case/bestie_config_use_case.dart';
import 'package:bestie_ui/bestie_ui.dart';
import 'package:intentions/intentions.dart';
import 'package:nocterm/nocterm.dart';

/// Left-pane page list for the config overlay.
@view
class SectionTabs extends StatelessComponent {
  const SectionTabs({
    required this.pages,
    required this.selectedPageId,
    this.onSelectPage,
    super.key,
  });

  final List<ConfigPage> pages;
  final String selectedPageId;

  /// Called with a page's index when it is clicked — the mouse equivalent of
  /// tabbing to that page.
  final void Function(int index)? onSelectPage;

  @override
  Component build(BuildContext context) {
    final appTheme = AppTheme.of(context);
    final theme = TuiTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 1),
        for (final (index, page) in pages.indexed)
          Hoverable(
            onTap: () => onSelectPage?.call(index),
            builder: (context, {required hovered}) {
              final isSelected = page.id == selectedPageId;
              return Container(
                height: 1,
                color: hovered && !isSelected ? appTheme.hover : null,
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: Row(
                  children: [
                    Text(
                      isSelected ? '┃ ' : '  ',
                      style: TextStyle(color: theme.primary),
                    ),
                    Text(
                      page.label,
                      style: TextStyle(
                        color: isSelected ? theme.primary : appTheme.muted,
                        fontWeight: isSelected
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}
