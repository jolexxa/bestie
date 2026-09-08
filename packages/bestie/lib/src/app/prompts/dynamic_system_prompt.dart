/// Months used to render the system prompt's date stamp without pulling in
/// `intl`. The order matters; index = `DateTime.month - 1`.
const List<String> _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// Told to the model up front: an AppContainer cannot canonicalize paths.
const String windowsSandboxNote =
    'You are running on Windows: `realpath` and '
    '`readlink -f` fail inside the sandbox; use relative paths or the working '
    'directory as given instead.';

/// Builds the dynamic portion of the system prompt (date + cwd, plus any
/// [platformNote]), resolved once at bootstrap and shared by the chat and
/// subagent prompts.
String buildDynamicSystemPrompt({
  required DateTime now,
  required String cwd,
  String? platformNote,
}) =>
    'It is ${_months[now.month - 1]} ${now.day}, ${now.year}. You are '
    'currently running the following directory: '
    '$cwd.${platformNote == null ? '' : ' $platformNote'}';
