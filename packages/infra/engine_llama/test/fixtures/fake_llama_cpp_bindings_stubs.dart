import 'package:llama_cpp_dart/llama_cpp_dart.dart';

/// Base for hand-written binding fakes: every native entry point a fake does
/// not override fails loudly instead of reaching a real library.
base class FakeLlamaCppBindingsStubs implements LlamaCppBindings {
  @override
  Never noSuchMethod(Invocation invocation) => throw UnsupportedError(
    'FakeLlamaCppBindings does not implement ${invocation.memberName}.',
  );
}
