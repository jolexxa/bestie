import 'dart:async';
import 'dart:io';

import 'package:engine_completions/engine_completions.dart';
import 'package:local_server/local_server.dart';
import 'package:mocktail/mocktail.dart';

final class MockModelEngine extends Mock implements ModelEngine {}

final class MockEngineCompletionRuntime extends Mock
    implements EngineCompletionRuntime {}

final class MockServerLog extends Mock implements ServerLog {}

final class MockServerLifetime extends Mock implements ServerLifetime {}

final class MockModelEngineStarter extends Mock implements ModelEngineStarter {}

final class MockHttpRequest extends Mock implements HttpRequest {}

final class MockHttpResponse extends Mock implements HttpResponse {}

final class MockHttpHeaders extends Mock implements HttpHeaders {}

final class MockLoadedModel extends Mock implements LoadedModel {
  /// A loaded model whose runtime reports [contextSize] and [maxAgents], an
  /// empty pool, and disposes and unloads cleanly.
  factory MockLoadedModel.serving({
    required int contextSize,
    required int maxAgents,
    StreamController<PoolSnapshot>? poolChanges,
  }) {
    final runtime = MockEngineCompletionRuntime();
    final pool = PoolSnapshot(
      contextSize: contextSize,
      maxAgents: maxAgents,
      agents: const [],
    );
    when(() => runtime.contextSize).thenReturn(contextSize);
    when(() => runtime.maxAgents).thenReturn(maxAgents);
    when(() => runtime.pool).thenReturn(pool);
    when(() => runtime.poolChanges).thenAnswer(
      (_) => poolChanges?.stream ?? const Stream.empty(),
    );
    when(runtime.dispose).thenAnswer((_) async {});
    when(runtime.closeAll).thenAnswer((_) async {});
    final model = MockLoadedModel._();
    when(() => model.runtime).thenReturn(runtime);
    when(() => model.deviceBytes).thenReturn(1234);
    when(model.unload).thenAnswer((_) async {});
    return model;
  }

  MockLoadedModel._();
}
