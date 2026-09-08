import 'package:intentions/intentions.dart';

/// A paper the answer drew on, for whoever credits sources.
@model
final class PaperSource {
  const PaperSource({required this.url, required this.title});

  final String url;
  final String title;
}
