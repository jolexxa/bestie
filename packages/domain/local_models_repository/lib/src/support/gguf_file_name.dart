import 'package:intentions/intentions.dart';
import 'package:path/path.dart' as p;

/// What a GGUF's file name says: whether it is a model at all, which split
/// file it is, and its quant.
@model
final class GgufFileName {
  GgufFileName(this.path, {required p.Context paths})
    : _paths = paths,
      baseName = paths.basename(path),
      _shard = _shardPattern.firstMatch(paths.basename(path));

  /// `model-Q4_K_M-00001-of-00003.gguf` and
  /// `model-Q4_K_M.gguf-00001-of-00003.gguf`.
  static final _shardPattern = RegExp(
    r'^(.+?)([-.])(\d{5})-of-(\d{5})\.gguf$',
    caseSensitive: false,
  );

  static final _extension = RegExp(r'\.gguf$', caseSensitive: false);

  /// Standard quant tokens (`Q4_K_M`, `IQ2_XXS`, `TQ1_0`, `Q8_0`), float types
  /// (`F16`, `BF16`) and microscaling formats (`MXFP4`, `NVFP4`).
  static final _quantPattern = RegExp(
    r'[._-]((?:[IT]?Q\d+_(?:K_[A-Z]+|[A-Z0-9]+|[A-Z]+)|[BF]F?\d+(?:_[A-Z]+)?'
    r'|(?:MX|NV)FP\d+))'
    r'(?:[._-]|$)',
    caseSensitive: false,
  );

  final String path;

  final String baseName;

  final p.Context _paths;

  final RegExpMatch? _shard;

  /// The name without its extension or split suffix.
  String get stem =>
      (_shard?.group(1) ?? baseName).replaceFirst(_extension, '');

  /// One-based.
  int get shardIndex => int.parse(_shard?.group(3) ?? '1');

  int get shardCount => int.parse(_shard?.group(4) ?? '1');

  /// A model's weights, rather than a vision projector or another file.
  bool get isModel =>
      _extension.hasMatch(baseName) &&
      !baseName.toLowerCase().contains('mmproj');

  bool get isFirstShard => shardIndex == 1;

  /// Uppercase, e.g. `Q4_K_M`, or null when the name carries none.
  String? get quantLabel =>
      _quantPattern.firstMatch(stem)?.group(1)?.toUpperCase();

  /// Every file of the model this one belongs to, first to last.
  List<String> get shardPaths => switch (_shard) {
    null => [path],
    final shard => [
      for (var index = 1; index <= shardCount; index++)
        _paths.normalize(
          _paths.join(
            _paths.dirname(path),
            '${shard.group(1)}${shard.group(2)}${_pad(index)}-of-'
            '${shard.group(4)}.gguf',
          ),
        ),
    ],
  };

  static String _pad(int index) => '$index'.padLeft(5, '0');
}
