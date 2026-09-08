import 'dart:convert';

import 'package:bestie_platform_abstractions/bestie_platform_abstractions.dart';
import 'package:intentions/intentions.dart';
import 'package:platform/platform.dart';
import 'package:process_host/process_host.dart';

@dataSource
class LinuxClipboardDataSource implements ClipboardDataSource {
  const LinuxClipboardDataSource({
    required this.platform,
    required this.runner,
  });

  final Platform platform;
  final ProcessRunner runner;

  @override
  Future<void> copy(String text) async {
    final isWayland =
        platform.environment['XDG_SESSION_TYPE'] == 'wayland' ||
        platform.environment.containsKey('WAYLAND_DISPLAY');
    final bytes = utf8.encode(text);
    if (isWayland) {
      await runner.run('wl-copy', stdin: bytes);
    } else {
      await runner.run(
        'xclip',
        arguments: const ['-selection', 'clipboard'],
        stdin: bytes,
      );
    }
  }
}
