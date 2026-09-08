import 'dart:async';

import 'package:bestie_config_view/bestie_config_view.dart';
import 'package:bestie_platform_abstractions/bestie_platform_abstractions.dart';
import 'package:bestie_provider_use_case/bestie_provider_use_case.dart';
import 'package:bestie_ui/bestie_ui.dart';
import 'package:blocterm/blocterm.dart';
import 'package:intentions/intentions.dart';
import 'package:nocterm/nocterm.dart';
import 'package:platform_repository/platform_repository.dart';
import 'package:provider_protocol/provider_protocol.dart';
import 'package:provider_repository/provider_repository.dart';
import 'package:tool_protocol/tool_protocol.dart'
    show ToolDefinition, ToolDefinitions;

/// Read-only Info page: app metadata, system stats, paths, registered
/// tools. Structure is defined in [infoLayout]; this component just
/// renders each entry.
@view
class InfoSection extends StatelessComponent {
  const InfoSection({
    required this.selectedIndex,
    required this.controller,
    required this.onSelect,
    super.key,
  });

  final int selectedIndex;
  final ScrollController controller;

  /// Moves the selection indicator to the clicked selectable row.
  final void Function(int index) onSelect;

  @override
  Component build(BuildContext context) {
    final appTheme = AppTheme.of(context);
    final platform = RepositoryProvider.of<OSPlatform>(context);
    final tools = RepositoryProvider.of<ToolDefinitions>(context).definitions;
    final app = RepositoryProvider.of<AppInfo>(context);
    final provider = RepositoryProvider.of<ProviderUseCase>(context);
    final layout = infoLayout(toolCount: tools.length);

    final items = <Component>[];
    var selectableIdx = 0;
    for (var i = 0; i < layout.length; i++) {
      final entry = layout[i];
      final selected = entry.selectable && selectableIdx == selectedIndex;
      final index = selectableIdx;
      if (entry.selectable) selectableIdx++;
      final showSeparator = _separatorAfter(layout, i);

      if (!entry.selectable) {
        items.add(
          _renderEntry(
            entry: entry,
            selected: false,
            hovered: false,
            showSeparator: showSeparator,
            platform: platform,
            tools: tools,
            app: app,
            provider: provider,
            theme: appTheme,
          ),
        );
        continue;
      }

      items.add(
        Hoverable(
          onTap: () => onSelect(index),
          builder: (context, {required hovered}) => _renderEntry(
            entry: entry,
            selected: selected,
            hovered: hovered,
            showSeparator: showSeparator,
            platform: platform,
            tools: tools,
            app: app,
            provider: provider,
            theme: appTheme,
          ),
        ),
      );
    }

    return ScrollableListShell(
      controller: controller,
      itemCount: items.length,
      itemBuilder: (_, i) => items[i],
      enableSelection: true,
      onSelectionCompleted: (text) => unawaited(
        RepositoryProvider.of<OSPlatformRepository>(
          context,
        ).copyToClipboard(text),
      ),
    );
  }

  /// Hide the trailing separator when the next entry is a section
  /// heading (the heading provides its own visual break) or when this is
  /// the final entry.
  static bool _separatorAfter(List<InfoEntry> layout, int i) {
    if (i + 1 >= layout.length) return false;
    return layout[i + 1] is! InfoHeader;
  }

  Component _renderEntry({
    required InfoEntry entry,
    required bool selected,
    required bool hovered,
    required bool showSeparator,
    required OSPlatform platform,
    required List<ToolDefinition> tools,
    required AppInfo app,
    required ProviderUseCase provider,
    required AppThemeData theme,
  }) => switch (entry) {
    InfoHeader(:final label) => SectionHeading(label: label),
    InfoLegend() => _legendRow(theme),
    InfoRow(kind: InfoRowKind.version) => _labeled(
      label: 'Version',
      value: app.version,
      selected: selected,
      hovered: hovered,
      showSeparator: showSeparator,
      theme: theme,
    ),
    InfoRow(kind: InfoRowKind.description) => _labeled(
      label: 'Description',
      value: app.description,
      selected: selected,
      hovered: hovered,
      showSeparator: showSeparator,
      theme: theme,
    ),
    InfoRow(kind: InfoRowKind.platform) => _labeled(
      label: 'Platform',
      value: '${platform.os.name} (${platform.architecture.name})',
      selected: selected,
      hovered: hovered,
      showSeparator: showSeparator,
      theme: theme,
    ),
    InfoRow(kind: InfoRowKind.provider) => _wrappingLabeled(
      label: 'Provider',
      value: _providerSummary(provider.status),
      selected: selected,
      hovered: hovered,
      showSeparator: showSeparator,
      theme: theme,
    ),
    InfoRow(kind: InfoRowKind.credits) => _wrappingLabeled(
      label: 'Credits',
      value: _creditsSummary(provider.lastCredits),
      selected: selected,
      hovered: hovered,
      showSeparator: showSeparator,
      theme: theme,
    ),
    InfoRow(kind: InfoRowKind.configPath) => _labeled(
      label: 'Config',
      value: platform.configFile,
      selected: selected,
      hovered: hovered,
      showSeparator: showSeparator,
      theme: theme,
    ),
    InfoRow(kind: InfoRowKind.tool, :final toolIndex) => _toolBlock(
      tool: tools[toolIndex!],
      selected: selected,
      hovered: hovered,
      showSeparator: showSeparator,
      theme: theme,
    ),
  };

  /// One-row label-value block.
  Component _labeled({
    required String label,
    required String value,
    required bool selected,
    required bool hovered,
    required AppThemeData theme,
    bool showSeparator = true,
  }) => SelectableBlock(
    selected: selected,
    hovered: hovered,
    showSeparator: showSeparator,
    rows: [
      SizedBox(
        height: 1,
        child: Row(
          children: [
            SizedBox(
              width: 20,
              child: Text(label, style: TextStyle(color: theme.muted)),
            ),
            Expanded(
              child: Text(
                value,
                style: TextStyle(color: theme.onBackground),
              ),
            ),
          ],
        ),
      ),
    ],
  );

  /// Label-value block whose value column wraps over multiple lines.
  Component _wrappingLabeled({
    required String label,
    required String value,
    required bool selected,
    required bool hovered,
    required AppThemeData theme,
    bool showSeparator = true,
  }) => SelectableBlock(
    selected: selected,
    hovered: hovered,
    showSeparator: showSeparator,
    rows: [
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 20,
            child: Text(label, style: TextStyle(color: theme.muted)),
          ),
          Expanded(
            child: Text(value, style: TextStyle(color: theme.onBackground)),
          ),
        ],
      ),
    ],
  );

  static String _providerSummary(ProviderStatus status) => switch (status) {
    ProviderStatusUnconfigured() => 'Not configured',
    ProviderStatusConnecting(:final model) =>
      'Connecting to ${model.qualified}…',
    ProviderStatusReady(:final providerName, :final model) =>
      '$providerName · ${model.name} (${model.id})',
    ProviderStatusFailed(:final failure) => 'Failed: ${failure.message}',
  };

  static String _creditsSummary(CreditsResult? credits) => switch (credits) {
    null => 'Not fetched yet — run "Refresh credits" from the palette.',
    CreditsFetched(:final credits) => switch (credits.remaining) {
      null =>
        '\$${credits.spent.toStringAsFixed(2)} spent'
            '${_spendWindowSuffix(credits.window)}',
      final remaining =>
        '\$${credits.spent.toStringAsFixed(2)} used of '
            '\$${(credits.spent + remaining).toStringAsFixed(2)} '
            '(\$${remaining.toStringAsFixed(2)} left)',
    },
    CreditsFailed(:final failure) => 'Failed: ${failure.message}',
    CreditsUnsupported() => 'Not offered by this provider.',
  };

  static String _spendWindowSuffix(SpendWindow window) => switch (window) {
    SpendWindow.lifetime => '',
    SpendWindow.monthToDate => ' this month',
  };

  Component _legendRow(AppThemeData theme) => SizedBox(
    height: 1,
    child: Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Row(
        children: [
          Text('*', style: TextStyle(color: theme.warning)),
          Text(' required', style: TextStyle(color: theme.muted)),
        ],
      ),
    ),
  );

  Component _toolBlock({
    required ToolDefinition tool,
    required bool selected,
    required bool hovered,
    required bool showSeparator,
    required AppThemeData theme,
  }) {
    final propsRaw = tool.parameters['properties'];
    final props = propsRaw is Map
        ? Map<String, Object?>.from(propsRaw)
        : const <String, Object?>{};
    final requiredRaw = tool.parameters['required'];
    final required = requiredRaw is List
        ? requiredRaw.map((e) => e.toString()).toSet()
        : const <String>{};

    return SelectableBlock(
      selected: selected,
      hovered: hovered,
      showSeparator: showSeparator,
      rows: [
        SizedBox(
          height: 1,
          child: Text(
            tool.name,
            style: TextStyle(
              color: theme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 2),
          child: Text(
            tool.description,
            style: TextStyle(color: theme.muted),
          ),
        ),
        if (props.isNotEmpty) const SizedBox(height: 1),
        for (final entry in props.entries)
          _paramRow(
            name: entry.key,
            definition: entry.value,
            isRequired: required.contains(entry.key),
            theme: theme,
          ),
      ],
    );
  }

  Component _paramRow({
    required String name,
    required Object? definition,
    required bool isRequired,
    required AppThemeData theme,
  }) {
    final defMap = definition is Map
        ? Map<String, Object?>.from(definition)
        : const <String, Object?>{};
    final type = defMap['type']?.toString() ?? '';
    final description = defMap['description']?.toString() ?? '';

    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 1,
            child: Row(
              children: [
                Text(name, style: TextStyle(color: theme.info)),
                if (isRequired)
                  Text('*', style: TextStyle(color: theme.warning)),
                if (type.isNotEmpty)
                  Text(' · $type', style: TextStyle(color: theme.muted)),
              ],
            ),
          ),
          if (description.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 2),
              child: Text(
                description,
                style: TextStyle(color: theme.muted),
              ),
            ),
        ],
      ),
    );
  }
}
