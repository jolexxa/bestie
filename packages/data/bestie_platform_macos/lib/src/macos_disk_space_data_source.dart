import 'package:bestie_platform_abstractions/bestie_platform_abstractions.dart';
import 'package:intentions/intentions.dart';
import 'package:posix_dart/posix_dart.dart';

@dataSource
class MacOSDiskSpaceDataSource implements DiskSpaceDataSource {
  MacOSDiskSpaceDataSource({required StatvfsReader reader}) : _reader = reader;

  final StatvfsReader _reader;

  @override
  int availableBytes(String path) => switch (_reader.statvfs(path)) {
    StatvfsSucceeded(:final snapshot) => snapshot.availableBytes,
    StatvfsFailed() => 0,
  };
}
