import 'package:intentions/intentions.dart';

/// A model this one was derived from, as listed under
/// `general.base_model.{index}.*`.
@model
final class GgufBaseModel {
  const GgufBaseModel({
    required this.index,
    this.name,
    this.organization,
    this.url,
    this.repoUrl,
  });

  final int index;
  final String? name;
  final String? organization;
  final String? url;
  final String? repoUrl;
}
