import 'package:file/file.dart';
import 'package:file/local.dart';
import 'package:intentions/intentions.dart';
import 'package:local_inference_protocol/local_inference_protocol.dart';
import 'package:model_index_store/src/json_file.dart';
import 'package:model_index_store/src/store_result.dart';

/// The model index at [path]: every model the inference server may load.
@dataSource
class ModelIndexStore {
  const ModelIndexStore({
    required this.path,
    FileSystem fileSystem = const LocalFileSystem(),
  }) : _fileSystem = fileSystem;

  final String path;
  final FileSystem _fileSystem;

  Future<StoreReadResult<ModelIndex>> read() =>
      readJsonFile(_fileSystem, path, ModelIndexMapper.fromJson);

  Future<StoreWriteResult> write(ModelIndex index) =>
      writeJsonFile(_fileSystem, path, index.toMap());
}
