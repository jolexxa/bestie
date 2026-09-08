import 'package:highlighting/highlighting.dart';
import 'package:highlighting/languages/all.dart';

bool _registered = false;

/// Registers every built-in language with the shared `highlight` instance.
/// Idempotent. Called automatically on first `highlightSpan` use.
void registerAllLanguages() {
  if (_registered) return;
  builtinLanguages.values.forEach(highlight.registerLanguage);
  _registered = true;
}

/// Returns `true` if [languageId] is a known built-in language.
bool isLanguageSupported(String languageId) {
  return builtinLanguages.containsKey(languageId);
}

/// Resolves a (possibly null or unknown) language hint to a safe language id.
/// Unknown languages fall back to `plaintext`.
String resolveLanguageId(String? languageHint) {
  if (languageHint == null) return 'plaintext';
  final normalized = languageHint.toLowerCase();
  if (isLanguageSupported(normalized)) return normalized;
  return 'plaintext';
}

/// Best-effort mapping of a file path to a language id, based on the path's
/// extension or basename. Returns `null` if nothing matches.
String? inferLanguageFromPath(String? path) {
  if (path == null) return null;
  final lower = path.toLowerCase();
  final slash = lower.lastIndexOf('/');
  final basename = slash >= 0 ? lower.substring(slash + 1) : lower;

  // Whole-filename matches (no extension, or extension is part of the name).
  final byName = _byFilename[basename];
  if (byName != null) return byName;

  final dot = basename.lastIndexOf('.');
  if (dot < 0) return null;
  final ext = basename.substring(dot + 1);
  return _byExtension[ext];
}

const _byExtension = <String, String>{
  'dart': 'dart',
  'rs': 'rust',
  'ts': 'typescript',
  'tsx': 'typescript',
  'js': 'javascript',
  'jsx': 'javascript',
  'mjs': 'javascript',
  'cjs': 'javascript',
  'py': 'python',
  'pyi': 'python',
  'go': 'go',
  'c': 'c',
  'h': 'c',
  'cpp': 'cpp',
  'cc': 'cpp',
  'cxx': 'cpp',
  'hpp': 'cpp',
  'hh': 'cpp',
  'hxx': 'cpp',
  'java': 'java',
  'kt': 'kotlin',
  'kts': 'kotlin',
  'swift': 'swift',
  'rb': 'ruby',
  'sh': 'bash',
  'bash': 'bash',
  'zsh': 'bash',
  'fish': 'bash',
  'md': 'markdown',
  'markdown': 'markdown',
  'json': 'json',
  'yaml': 'yaml',
  'yml': 'yaml',
  'toml': 'ini',
  'xml': 'xml',
  'html': 'xml',
  'htm': 'xml',
  'css': 'css',
  'scss': 'scss',
  'less': 'less',
  'sql': 'sql',
  'cs': 'csharp',
  'fs': 'fsharp',
  'php': 'php',
  'lua': 'lua',
  'r': 'r',
  'pl': 'perl',
  'scala': 'scala',
  'clj': 'clojure',
  'cljs': 'clojure',
  'ex': 'elixir',
  'exs': 'elixir',
  'erl': 'erlang',
  'hs': 'haskell',
  'ml': 'ocaml',
  'mli': 'ocaml',
  'nim': 'nim',
  'zig': 'zig',
  'jl': 'julia',
  'vim': 'vim',
  'tex': 'latex',
  'diff': 'diff',
  'patch': 'diff',
};

const _byFilename = <String, String>{
  'dockerfile': 'dockerfile',
  'makefile': 'makefile',
  'gnumakefile': 'makefile',
  'cmakelists.txt': 'cmake',
};
