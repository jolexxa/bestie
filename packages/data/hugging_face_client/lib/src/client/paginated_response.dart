import 'package:intentions/intentions.dart';
import 'package:meta/meta.dart';

/// A page of results from a paginated HuggingFace API endpoint.
@model
@immutable
class PaginatedResponse<T> {
  /// Creates a [PaginatedResponse].
  const PaginatedResponse({required this.items, this.nextUrl});

  /// The items on this page.
  final List<T> items;

  /// The URL for the next page, parsed from the `Link` header.
  ///
  /// `null` when this is the last page.
  final Uri? nextUrl;

  /// Whether more pages are available.
  bool get hasMore => nextUrl != null;
}

final _nextLink = RegExp(r'<([^>]+)>;\s*rel="next"');

/// Parses the `rel="next"` URL from an RFC 8288 `Link` header, or null when
/// there is no next page.
Uri? parseLinkNext(String? linkHeader) =>
    switch (_nextLink.firstMatch(linkHeader ?? '')) {
      null => null,
      final match => Uri.parse(match.group(1)!),
    };
