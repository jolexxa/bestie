import 'package:bestie_platform_abstractions/bestie_platform_abstractions.dart';
import 'package:file/file.dart' show FileSystem;

/// Reads the bundled `CREDITS.md` the platform layer resolved, falling back to
/// a placeholder when it cannot be read.
String readCredits(FileSystem fileSystem, OSPlatform platform) {
  try {
    return fileSystem.file(platform.creditsPath).readAsStringSync();
  } on Object {
    return '# Credits\n\nCredits are unavailable.';
  }
}
