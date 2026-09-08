import 'package:intentions/intentions.dart';

/// External disk-space reader.
@dataSource
// This is a platform abstraction interface, not a utility function.
// ignore: one_member_abstracts
abstract interface class DiskSpaceDataSource {
  /// Returns available bytes for the filesystem containing [path].
  int availableBytes(String path);
}
