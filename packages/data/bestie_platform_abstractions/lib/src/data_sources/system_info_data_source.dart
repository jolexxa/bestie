import 'package:bestie_platform_abstractions/src/models/system_info_snapshot.dart';
import 'package:intentions/intentions.dart';

/// External source of current system resource information.
@dataSource
// This is a platform abstraction interface, not a utility function.
// ignore: one_member_abstracts
abstract interface class SystemInfoDataSource {
  /// Reads a fresh system information snapshot.
  SystemInfoSnapshot readSystemInfo();
}
