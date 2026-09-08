import 'package:dart_mappable/dart_mappable.dart';

part 'lowered_policy.mapper.dart';

/// The access a [Grant] confers. Read implies execute; there is no separate
/// execute bit.
@MappableEnum()
enum GrantAccess {
  /// Read (and execute) the subtree.
  read,

  /// Read, execute, and write the subtree.
  readWrite,

  /// List the directory only — its entries are visible but their contents stay
  /// unreadable.
  listDir,
}

/// A single filesystem grant on [path] at [access], applied recursively.
@MappableClass()
class Grant with GrantMappable {
  /// Grants [access] on [path].
  const Grant(this.path, this.access);

  /// The canonical path granted.
  final String path;

  /// The access conferred.
  final GrantAccess access;
}

/// A single native read-deny carve-out. macOS only; [path] is a concrete path,
/// globs already enumerated by the lowering.
@MappableClass()
class Deny with DenyMappable {
  /// Denies reads of the concrete [path].
  const Deny(this.path);

  /// The canonical path denied.
  final String path;
}

/// A lowered, fully-resolved policy with nothing left to interpret.
@MappableClass(discriminatorKey: 'type')
sealed class LoweredPolicy with LoweredPolicyMappable {
  /// Const base for the sealed hierarchy.
  const LoweredPolicy();
}

/// Grants only — the shape Landlock and AppContainer can express.
@MappableClass(discriminatorValue: 'grant')
final class GrantProgram extends LoweredPolicy with GrantProgramMappable {
  /// Wraps the [grants] to apply.
  const GrantProgram(this.grants);

  /// The grants to apply.
  final List<Grant> grants;
}

/// Grants plus native read-denies — the shape only Seatbelt can express.
@MappableClass(discriminatorValue: 'masked')
final class MaskedProgram extends LoweredPolicy with MaskedProgramMappable {
  /// Wraps the [grants] and the native [denies].
  const MaskedProgram(this.grants, this.denies);

  /// The grants to apply.
  final List<Grant> grants;

  /// The native read-denies to apply.
  final List<Deny> denies;
}
