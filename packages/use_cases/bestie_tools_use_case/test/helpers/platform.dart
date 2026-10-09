import 'package:bestie_platform_abstractions/bestie_platform_abstractions.dart';

/// The platform every test runs against, so paths read the same on any host.
final linuxPlatform = LinuxPlatform(
  architecture: OSArchitecture.linuxX64,
  homeDir: '/home/j',
  tempDir: '/tmp',
  workingDirectory: '/work',
  bestieDir: '/home/j/.bestie',
  configFile: '/home/j/.bestie/bestie.json',
  conversationsDir: '/home/j/.bestie/conversations',
  curlLibraryPath: '/curl',
  caCertPath: '/ca.pem',
  creditsPath: '/CREDITS.md',
  serverExecutable: const ProgramCommand(executable: '/bestie_server'),
);
