import 'package:local_models_repository/src/models/model_source.dart';
import 'package:local_models_repository/src/support/gguf_file_name.dart';
import 'package:path/path.dart' as p;

/// `…/models--org--repo/snapshots/<revision>/…`, the Hugging Face cache.
final _huggingFaceCache = RegExp(
  r'models--([^/\\]+?)--([^/\\]+)[/\\]snapshots[/\\]([^/\\]+)[/\\]',
);

/// The Hugging Face repo a GGUF's location suggests: a Hugging Face cache
/// snapshot, or an `org/repo/file.gguf` layout under [root] as LM Studio and
/// bestie's own models folder use. Split quants may sit one folder deeper,
/// in `org/repo/<quant>/`, as repos often ship them.
InferredRepo? inferRepo(String root, String path, p.Context paths) {
  final segments = paths.split(paths.relative(path, from: root));
  final depth = GgufFileName(path, paths: paths).shardCount > 1 ? {3, 4} : {3};
  return switch (_huggingFaceCache.firstMatch(path)) {
    final cache? => InferredRepo(
      repo: '${cache.group(1)}/${cache.group(2)}',
      revision: cache.group(3),
    ),
    null when depth.contains(segments.length) => InferredRepo(
      repo: '${segments[0]}/${segments[1]}',
    ),
    null => null,
  };
}
