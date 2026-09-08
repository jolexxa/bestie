import 'dart:async';

import 'package:bestie_config_view/src/models/credits_document.dart';
import 'package:bestie_ui/bestie_ui.dart';
import 'package:blocterm/blocterm.dart';
import 'package:intentions/intentions.dart';
import 'package:markdown_highlighted/markdown_highlighted.dart';
import 'package:nocterm/nocterm.dart' hide MarkdownStyleSheet, MarkdownText;
import 'package:platform_repository/platform_repository.dart';

/// Read-only Credits page.
@view
class CreditsSection extends StatelessComponent {
  const CreditsSection({required this.controller, super.key});

  /// Shared config scroll controller.
  final ScrollController controller;

  @override
  Component build(BuildContext context) {
    final theme = AppTheme.of(context);
    final credits = RepositoryProvider.of<CreditsDocument>(context);

    return ScrollableListShell(
      controller: controller,
      itemCount: 1,
      cacheExtent: 40,
      enableSelection: true,
      onSelectionCompleted: (text) => unawaited(
        RepositoryProvider.of<OSPlatformRepository>(
          context,
        ).copyToClipboard(text),
      ),
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(left: 2, bottom: 1),
        child: MarkdownView(
          credits.markdown,
          theme: MarkdownTheme(
            paragraphStyle: TextStyle(color: theme.onBackground),
          ),
          highlightTheme: syntaxThemeFor(theme),
        ),
      ),
    );
  }
}
