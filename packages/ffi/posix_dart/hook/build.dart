import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';

/// posix_dart has no native libraries to bundle — libc is already
/// loaded into every Dart process on POSIX systems. The build hook
/// exists only to satisfy the `code_assets` framework contract.
Future<void> main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) return;
  });
}
