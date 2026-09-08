import 'dart:io';

import 'package:mocktail/mocktail.dart';
import 'package:win32_dart/win32_dart.dart';

/// The `win32_dart` wrappers are plain classes so they mock directly, which
/// keeps these tests talking in results rather than in Win32 call signatures.
class MockMemoryQuery extends Mock implements MemoryQuery {}

class MockProcessorQuery extends Mock implements ProcessorQuery {}

class MockDiskQuery extends Mock implements DiskQuery {}

class MockHardLinkQuery extends Mock implements HardLinkQuery {}

class MockDllSearchPath extends Mock implements DllSearchPath {}

class MockClipboard extends Mock implements Clipboard {}

class MockClipboardSession extends Mock implements ClipboardSession {}

class MockStdioRedirect extends Mock implements StdioRedirect {}

class MockStderrRedirection extends Mock implements StderrRedirection {}

class MockConsoleMode extends Mock implements ConsoleMode {}

class MockCrtFd extends Mock implements CrtFd {}

class MockStdout extends Mock implements Stdout {}

class MockStdin extends Mock implements Stdin {}

/// A failure with a code, for asserting that one is carried through rather
/// than swallowed.
const failure = Win32Failure(
  function: 'GetDiskFreeSpaceExW',
  code: 3,
  message: 'The system cannot find the path specified.',
  channel: Win32ErrorChannel.lastError,
);
