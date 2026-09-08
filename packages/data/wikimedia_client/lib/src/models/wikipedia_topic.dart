import 'package:intentions/intentions.dart';

@model
final class WikipediaTopic {
  const WikipediaTopic({
    required this.title,
    required this.url,
    required this.description,
  });

  final String title;

  /// Always an address, whether the service gave one or it had to be built
  /// from the title.
  final String url;

  /// Plain text, with the service's markup taken back out.
  final String description;
}
