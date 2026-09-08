import 'dart:convert';

import 'package:bestie_platform_abstractions/bestie_platform_abstractions.dart';
import 'package:intentions/intentions.dart';
import 'package:process_host/process_host.dart';

@dataSource
class MacOSClipboardDataSource implements ClipboardDataSource {
  const MacOSClipboardDataSource({required this.runner});

  final ProcessRunner runner;

  @override
  Future<void> copy(String text) async {
    await runner.run('pbcopy', stdin: utf8.encode(text));
  }
}
