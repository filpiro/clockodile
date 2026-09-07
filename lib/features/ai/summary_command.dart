import 'dart:convert';

import '../../data/db/database.dart';

/// Everything about a Note Summary that can be decided without spawning
/// anything: what to run, what to say, and what the CLI's stdout meant.
/// Touches no `Process` and no `Platform` — see `summary_runner.dart` for the
/// half that does. This file is the feature's test seam.

/// A command ready to spawn: a binary and its argument list. Never a shell
/// string — under WSL the shell string is one argument to `wsl.exe`.
class AiCommand {
  final String executable;
  final List<String> arguments;
  const AiCommand(this.executable, this.arguments);
}

/// Below this many words a Note is already short enough to leave alone.
const _minWordsForSummary = 10;

bool hasEnoughWordsForSummary(String note) =>
    note.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length >=
    _minWordsForSummary;

String buildSummaryPrompt(String text) =>
    '''
Summarize the following email into the shortest possible italian line for a
time-tracking note field (hard cap: 15 words, fewer is better—don't pad to
reach the limit). Capture the core request or feedback. No greetings, no
filler, no quotes—just the essence as a plain statement.

Email:
"""
$text
"""''';

/// The binary and its arguments, before any WSL wrapping. No prompt argument:
/// the prompt travels over stdin, which removes both the command-line length
/// limit and the escaping problem for the user's pasted email.
List<String> _argv(AiProvider provider, String model, String effort) =>
    switch (provider) {
      AiProvider.claudeCode => [
        'claude',
        '-p',
        '--output-format',
        'json',
        '--model',
        model,
        '--effort',
        effort,
      ],
      // ponytail: ticket 03 adds these; the runner turns the throw into the
      // same error banner as any other failed generation.
      AiProvider.codex || AiProvider.opencode => throw UnimplementedError(
        'Provider ${provider.name} non ancora supportato',
      ),
    };

/// Single-quotes [value] for a POSIX shell, closing and reopening the quote
/// around each embedded `'`. This is the actual defense against a hostile
/// model/effort value; the Settings validator only exists to say so honestly.
String shellQuote(String value) => "'${value.replaceAll("'", r"'\''")}'";

AiCommand buildAiCommand({
  required AiProvider provider,
  required String model,
  required String effort,
  required bool wslMode,
  required String workingDirectory,
}) {
  final argv = _argv(provider, model, effort);
  if (!wslMode) return AiCommand(argv.first, argv.sublist(1));
  // A *login* shell is not optional: the CLIs live under paths that only the
  // shell's own startup files put on PATH (`wsl.exe -e claude` fails). See
  // ADR 0002.
  return AiCommand('wsl.exe', [
    '--cd',
    workingDirectory,
    '-e',
    'bash',
    '-lc',
    argv.map(shellQuote).join(' '),
  ]);
}

/// The summary the CLI produced, or null for "nothing usable" — no output,
/// blank output, or output this provider's format does not explain. Null and
/// the empty string are deliberately different: only null is a failure.
String? parseAiResult(AiProvider provider, String stdout) {
  final text = switch (provider) {
    AiProvider.claudeCode => _claudeResult(stdout),
    AiProvider.codex || AiProvider.opencode => null,
  };
  final trimmed = text?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}

/// `claude --output-format json` prints one object whose `result` is the answer.
String? _claudeResult(String stdout) {
  try {
    final decoded = jsonDecode(stdout.trim());
    return decoded is Map && decoded['result'] is String
        ? decoded['result'] as String
        : null;
  } on FormatException {
    return null;
  }
}
