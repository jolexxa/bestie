import 'package:meta/meta.dart';

/// A model advertised by an inference endpoint.
@immutable
final class InferenceModel {
  const InferenceModel({required this.id, this.ownedBy, this.created});

  final String id;

  final String? ownedBy;

  final DateTime? created;

  @override
  bool operator ==(Object other) =>
      other is InferenceModel &&
      other.id == id &&
      other.ownedBy == ownedBy &&
      other.created == created;

  @override
  int get hashCode => Object.hash(id, ownedBy, created);

  @override
  String toString() => 'InferenceModel($id)';
}
