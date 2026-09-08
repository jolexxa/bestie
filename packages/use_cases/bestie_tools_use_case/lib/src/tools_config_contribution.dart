import 'package:bestie_tools_use_case/src/tools_config_keys.dart';
import 'package:config_protocol/config_protocol.dart';
import 'package:intentions/intentions.dart';

@model
final class ToolsConfigContribution implements ConfigContribution {
  ToolsConfigContribution() : configKeys = ToolsConfigKeys.defaults();

  final ToolsConfigKeys configKeys;

  @override
  Iterable<ConfigEntry> get entries => [
    globalEntry(
      key: configKeys.concurrentTools,
      field: NumericField<int>(
        label: 'Concurrent Tools',
        description:
            'How many tool calls may run at once. Each runs off the '
            'interface thread, so lowering this only trades tool speed '
            'for room the model can generate in. Applies immediately.',
        min: minConcurrentTools,
        max: maxConcurrentTools,
        step: 1,
      ),
    ),
  ];
}
