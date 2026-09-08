import 'package:files_data_source/files_data_source.dart';
import 'package:intentions/intentions.dart';

/// A window onto a session's transcript.
@model
final class TranscriptPage {
  const TranscriptPage({
    required this.body,
    required this.totalLines,
    this.isLive = false,
  });

  /// A window that reached nothing.
  TranscriptPage.empty({
    required int at,
    required int totalChars,
    required this.totalLines,
    this.isLive = false,
  }) : body = Excerpt(
         text: '',
         start: CharPlace(at),
         extent: CharPlace(totalChars),
       );

  /// The characters read, placed in the whole of the transcript — settled
  /// and live together.
  final Excerpt<CharPlace> body;

  /// Lines the transcript holds.
  final int totalLines;

  /// Whether something was still writing to the transcript when this was
  /// read.
  final bool isLive;
}
