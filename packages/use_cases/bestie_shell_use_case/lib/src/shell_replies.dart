import 'package:bestie_shell_use_case/src/shell_tools.dart';
import 'package:files_data_source/files_data_source.dart';
import 'package:shell_repository/shell_repository.dart';

/// Told to the model in place of the empty string, which reads as a fault.
const String noOutput = '[no output]';

/// The two tellings of what a command printed: an answer carries the output,
/// a report only says how much there is.
enum ShellReply { answer, report }

extension ShellPages on TranscriptPage {
  /// This page told as [reply], within [maxChars]. [id] names the call to read
  /// back under; [lead] opens a report whose outcome has no words of its own.
  String told(
    ShellReply reply, {
    required String id,
    required int maxChars,
    String lead = '',
  }) => switch (reply) {
    ShellReply.answer => _printed(id, maxChars),
    ShellReply.report => lead.isEmpty ? _measured : '$lead $_measured',
  };

  int get _totalChars => body.extent.offset;

  /// What the command printed, or as much of the end as fits beside the note
  /// saying how much there was and where to read the rest.
  String _printed(String id, int maxChars) {
    if (_totalChars == 0) return noOutput;
    // This can still be the whole of it after giving way, and the whole
    // needs nothing said about it.
    return body.told(
      maxChars,
      (shown) => shown.isWhole
          ? shown.text
          : _under(shown.text, _shownNote(shown.text.length, id)),
    );
  }

  /// How much there was in all, and how much of the end of it is above.
  String _shownNote(int shown, String id) =>
      '[$totalLines lines, $_totalChars chars in all; '
      'the last $shown chars shown. Call id "$id".]';

  /// How much there is to read back, and nothing of it.
  String get _measured =>
      _totalChars == 0 ? noOutput : '$totalLines lines, $_totalChars chars.';

  /// This page, held to [maxChars], and where a further read of the call [id]
  /// carries on from.
  String read(String id, {required int maxChars}) {
    if (_totalChars == 0) return noOutput;
    if (body.text.isEmpty) {
      return isLive && body.remaining == 0
          ? _caughtUp(body.next.offset)
          : '[nothing at ${body.start.offset}; $_totalChars chars in all]';
    }
    return body.told(maxChars, (shown) {
      if (shown.remaining > 0) return _under(shown.text, _carryOn(shown, id));
      return isLive
          ? _under(shown.text, _caughtUp(shown.next.offset))
          : shown.text;
    });
  }

  /// Where [shown] stopped, how much is behind it, and the read that picks
  /// the call [id] up from there.
  String _carryOn(Excerpt<CharPlace> shown, String id) =>
      '[chars ${shown.start.offset} to ${shown.next.offset} of $_totalChars; '
      '${shown.remaining} to go — '
      '$bashReadName(id: "$id", offset: ${shown.next.offset})]';

  /// Guidance at the end of a recording still being written.
  String _caughtUp(int at) =>
      '[Caught up at $at. Still running — it notifies on completion.]';
}

/// [note] under [text], with a blank line between them — or on its own, where
/// there was no room for any text at all.
String _under(String text, String note) =>
    text.isEmpty ? note : '$text\n\n$note';
