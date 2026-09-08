import 'package:bestie_platform_abstractions/bestie_platform_abstractions.dart';
import 'package:intentions/intentions.dart';
import 'package:win32_dart/win32_dart.dart';

@dataSource
class WindowsExecutableLinkDataSource implements ExecutableLinkDataSource {
  /// [hardLink] defaults to the host's Win32 surface; pass one to substitute a
  /// double.
  WindowsExecutableLinkDataSource({HardLinkQuery? hardLink})
    : _hardLink = hardLink ?? HardLinkQuery(win32);

  final HardLinkQuery _hardLink;

  @override
  ExecutableLinkResult link({
    required String linkPath,
    required String targetPath,
  }) => switch (_hardLink.create(linkPath: linkPath, targetPath: targetPath)) {
    HardLinkSucceeded() => const ExecutableLinkCreated(),
    HardLinkFailed(:final failure) => ExecutableLinkFailed(failure.message),
  };
}
