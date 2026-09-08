import 'package:intentions/intentions.dart';

@model
final class ArxivPaper {
  const ArxivPaper({
    required this.id,
    required this.title,
    required this.authors,
    required this.published,
    required this.summary,
    this.category,
  });

  /// arXiv's identifier, which is also the paper's address.
  final String id;

  final String title;
  final List<String> authors;
  final DateTime published;

  /// The abstract, trimmed.
  final String summary;

  final String? category;
}
