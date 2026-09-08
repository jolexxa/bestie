import 'package:intentions/intentions.dart';

/// A topic the answer drew on, for whoever credits sources.
@model
final class TopicSource {
  const TopicSource({required this.url, required this.title});

  final String url;
  final String title;
}
