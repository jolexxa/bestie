import 'package:dart_mappable/dart_mappable.dart';

part 'role.mapper.dart';

@MappableEnum()
enum Role {
  @MappableValue('system')
  system,
  @MappableValue('user')
  user,
  @MappableValue('assistant')
  assistant,
  @MappableValue('tool')
  tool,
}
