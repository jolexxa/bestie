import 'package:intentions/intentions.dart';

/// One hit. A news hit is a hit that also knows who published it and when.
@model
final class SearchResult {
  const SearchResult({
    required this.title,
    required this.url,
    required this.snippet,
    this.source,
    this.published,
  });

  final String title;
  final String url;
  final String snippet;

  final String? source;
  final DateTime? published;
}
