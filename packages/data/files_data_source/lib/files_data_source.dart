/// Filesystem access for anything that reads, writes, or pages files.
library;

export 'package:tool_protocol/tool_protocol.dart'
    show Anchor, BytePlace, CharPlace, Excerpt, LinePlace, TextPlace;

export 'src/files_data_source.dart';
export 'src/models/byte_record.dart';
export 'src/models/directory_entry.dart';
export 'src/models/file_facts.dart';
export 'src/models/file_kind.dart';
export 'src/models/record_cursor.dart';
export 'src/models/stored_body.dart';
export 'src/models/text_extent.dart';
export 'src/record_file.dart';
