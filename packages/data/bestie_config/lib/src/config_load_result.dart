import 'package:intentions/intentions.dart';

@model
sealed class ConfigLoadResult {
  const ConfigLoadResult();
}

@model
final class ConfigLoaded extends ConfigLoadResult {
  const ConfigLoaded();
}

@model
final class ConfigStartedFresh extends ConfigLoadResult {
  const ConfigStartedFresh();
}

@model
final class ConfigRecovered extends ConfigLoadResult {
  const ConfigRecovered({required this.backupPath});

  final String backupPath;
}
