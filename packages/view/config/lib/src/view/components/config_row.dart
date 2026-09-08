import 'package:bestie_config_view/src/view/components/origin_label.dart';
import 'package:bestie_config_view/src/view/components/selectable_block.dart';
import 'package:bestie_ui/bestie_ui.dart';
import 'package:config_repository/config_repository.dart';
import 'package:intentions/intentions.dart';
import 'package:nocterm/nocterm.dart';

/// Renders a single config parameter.
///
/// **Browsing / single-line edit** — 4 rows tall:
/// 1. Label + overridden chip + value (or single-line editor) + adjust hint
/// 2. Description (or blank while single-line editing)
/// 3. Error message or blank
/// 4. Outline divider (full pane width)
///
/// **Multi-line edit** (`maxLines > 1`) — `maxLines + 3` rows:
/// 1. Label + overridden chip
/// 2..maxLines+1. Multi-line editor (height locked via `minLines == maxLines`)
/// maxLines+2. Error message or blank
/// maxLines+3. Outline divider
///
/// Gutter + separator are supplied by [SelectableBlock]; this widget only
/// constructs the content rows.
@view
class ConfigRow extends StatelessComponent {
  const ConfigRow({
    required this.entry,
    required this.resolver,
    required this.targetScope,
    required this.isSelected,
    required this.isEditing,
    this.hovered = false,
    this.editController,
    this.editError,
    this.onConfirm,
    super.key,
  });

  final ConfigEntry entry;
  final ConfigView resolver;
  final ConfigScope? targetScope;
  final bool isSelected;
  final bool isEditing;
  final bool hovered;
  final TextEditingController? editController;
  final String? editError;
  final ValueChanged<String>? onConfirm;

  @override
  Component build(BuildContext context) {
    final theme = AppTheme.of(context);

    final display = _display(theme);
    final value = display.value;
    final displayValue = _displayValue(value);
    final validation = field.validateValue(value);
    final overridden = display.overridden;
    final source = display.source;
    final maxLines = field.maxLines;
    final isMultiLineEdit = isEditing && maxLines > 1;
    final isMultiLineBrowse = !isEditing && maxLines > 1;

    final valueColor = switch (validation) {
      Valid() => overridden ? theme.onBackground : theme.muted,
      Invalid() => theme.error,
    };

    final labelLine = _labelRow(
      theme,
      source: source,
      displayValue: displayValue,
      valueColor: valueColor,
      overridden: overridden,
      isMultiLineEdit: isMultiLineEdit,
      isMultiLineBrowse: isMultiLineBrowse,
    );

    final descriptionRow = SizedBox(
      height: 1,
      child: Text(
        isEditing && !isMultiLineEdit ? '' : field.description,
        style: TextStyle(color: theme.muted),
      ),
    );

    final editorBlock = isMultiLineEdit
        ? SizedBox(
            height: maxLines.toDouble(),
            child: _buildTextField(theme),
          )
        : null;

    final feedbackRow = SizedBox(
      height: 1,
      child: _buildFeedback(theme, validation),
    );

    return SelectableBlock(
      selected: isSelected,
      modified: overridden,
      hovered: hovered,
      rows: [
        labelLine,
        if (editorBlock != null) editorBlock else descriptionRow,
        feedbackRow,
      ],
    );
  }

  Component _labelRow(
    AppThemeData theme, {
    required OriginLabel? source,
    required String displayValue,
    required Color valueColor,
    required bool overridden,
    required bool isMultiLineEdit,
    required bool isMultiLineBrowse,
  }) => SizedBox(
    height: 1,
    child: Row(
      children: [
        Text(
          field.label,
          style: TextStyle(
            color: isSelected ? theme.onBackground : theme.onSurface,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        Expanded(child: const SizedBox.shrink()),
        if (source != null && !isMultiLineEdit) ...[
          Text(source.text, style: TextStyle(color: source.color)),
          const SizedBox(width: 2),
        ],
        if (isEditing && !isMultiLineEdit)
          SizedBox(width: 16, child: _buildTextField(theme))
        else if (!isEditing) ...[
          Text(
            isMultiLineBrowse
                ? _multiLineSummary(displayValue, overridden)
                : displayValue,
            style: TextStyle(color: valueColor),
          ),
          if (isSelected && !isMultiLineBrowse)
            Text('  ◂ ▸', style: TextStyle(color: theme.muted)),
        ],
        const SizedBox(width: 2),
      ],
    ),
  );

  ConfigFieldBase get field => entry.field;

  static const _mask = '••••••••';

  /// Secrets stay masked while browsing; editing shows the real text.
  String _displayValue(Object? value) {
    final formatted = field.formatValue(value);
    return field.secret && formatted.isNotEmpty ? _mask : formatted;
  }

  /// Resolves this row's own address. If another address wins resolution,
  /// entry-level source labeling can describe that source.
  _ConfigRowDisplay _display(AppThemeData theme) {
    final address = entry.addressFor(targetScope: targetScope);
    if (address == null) {
      return const _ConfigRowDisplay.empty();
    }

    final inspected = resolver.inspectBase(address);
    final source = inspected.inheritedInto(address)
        ? _inheritedLabel(theme, inspected.source)
        : inspected.isDefault
        ? null
        : OriginLabel(text: 'set', color: theme.info);
    return _ConfigRowDisplay(
      value: inspected.value,
      source: source,
      overridden: resolver.isExplicitBase(address),
    );
  }

  OriginLabel? _inheritedLabel(
    AppThemeData theme,
    ConfigAddressBase? source,
  ) {
    final sourceLabel = entry.sourceLabel;
    if (source != null && sourceLabel != null && _matchesSourceLabel(source)) {
      return OriginLabel(text: sourceLabel.label, color: theme.muted);
    }
    return OriginLabel(text: 'inherited', color: theme.muted);
  }

  bool _matchesSourceLabel(ConfigAddressBase source) {
    final sourceLabel = entry.sourceLabel;
    return sourceLabel != null && source.key.id == sourceLabel.key.id;
  }

  /// Compact stand-in for the value column when the field is too big
  /// to render inline (multi-line opaque fields). The full text is
  /// only ever shown via the editor.
  String _multiLineSummary(String displayValue, bool overridden) {
    if (displayValue.isEmpty) return overridden ? '(empty)' : '(default)';
    final lines = '\n'.allMatches(displayValue).length + 1;
    return overridden
        ? '${displayValue.length} chars · $lines lines'
        : '(default · $lines lines)';
  }

  Component _buildTextField(AppThemeData theme) => TextField(
    controller: editController,
    focused: true,
    maxLines: field.maxLines,
    minLines: field.maxLines,
    style: TextStyle(color: theme.info),
    onSubmitted: (text) => onConfirm?.call(text),
  );

  /// Feedback line: edit error while editing, otherwise the persisted-value
  /// validation. Blank when neither applies.
  Component _buildFeedback(AppThemeData theme, Validation validation) {
    if (isEditing) {
      if (editError == null) return const SizedBox();
      return Text('⚠ $editError', style: TextStyle(color: theme.error));
    }
    if (validation is Invalid) {
      return Text(
        '⚠ ${validation.message}',
        style: TextStyle(color: theme.error),
      );
    }
    return const SizedBox();
  }
}

final class _ConfigRowDisplay {
  const _ConfigRowDisplay({
    required this.value,
    required this.source,
    required this.overridden,
  });

  const _ConfigRowDisplay.empty()
    : value = null,
      source = null,
      overridden = false;

  final Object? value;
  final OriginLabel? source;
  final bool overridden;
}
