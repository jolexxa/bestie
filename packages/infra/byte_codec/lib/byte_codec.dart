/// A byte writer that can be reused and a reader that can be moved, for
/// hand-rolled binary formats written a record at a time and read by seeking,
/// with nothing here allocating per record.
library;

export 'src/byte_reader.dart';
export 'src/byte_writer.dart';
