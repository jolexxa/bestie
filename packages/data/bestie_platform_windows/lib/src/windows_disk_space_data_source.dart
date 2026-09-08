import 'package:bestie_platform_abstractions/bestie_platform_abstractions.dart';
import 'package:intentions/intentions.dart';
import 'package:win32_dart/win32_dart.dart';

@dataSource
class WindowsDiskSpaceDataSource implements DiskSpaceDataSource {
  /// [disk] defaults to the host's Win32 surface; pass one to substitute a
  /// double.
  WindowsDiskSpaceDataSource({DiskQuery? disk})
    : _disk = disk ?? DiskQuery(win32);

  final DiskQuery _disk;

  @override
  int availableBytes(String path) => switch (_disk.space(path)) {
    DiskSpaceSucceeded(:final space) => space.availableBytes,
    DiskSpaceFailed() => 0,
  };
}
