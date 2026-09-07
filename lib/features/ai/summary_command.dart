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
      AiProvider.codex => [
        'codex',
        'exec',
        '--json',
        ..._flag('-m', model),
        // Codex takes reasoning effort as a config override, not a flag.
        if (effort.isNotEmpty) ...['-c', 'model_reasoning_effort=$effort'],
      ],
      AiProvider.opencode => [
        'opencode',
        'run',
        '--format',
        'json',
        ..._flag('-m', model),
        ..._flag('--variant', effort),
      ],
    };

/// An empty value means the CLI keeps its own default: pass nothing at all
/// rather than the flag with an empty argument.
List<String> _flag(String name, String value) =>
    value.isEmpty ? const [] : [name, value];

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
}) => _wrap(_argv(provider, model, effort), wslMode, workingDirectory);

/// The cheapest possible "is this CLI here?": the binary and `--version`, with
/// the same WSL wrapping a real run would get, so a pass here means a real run
/// can at least start.
AiCommand buildVersionCommand({
  required AiProvider provider,
  required bool wslMode,
}) => _wrap([_binary(provider), '--version'], wslMode, null);

String _binary(AiProvider provider) => switch (provider) {
  AiProvider.claudeCode => 'claude',
  AiProvider.codex => 'codex',
  AiProvider.opencode => 'opencode',
};

/// The message shown when [provider]'s CLI does not answer `--version`.
/// [suggestWsl] because on Windows a CLI installed inside WSL is by far the
/// most common reason for this to fail.
String cliMissingMessage({
  required AiProvider provider,
  required bool suggestWsl,
}) {
  final binary = _binary(provider);
  return suggestWsl
      ? 'CLI "$binary" non trovata. Se è installata in WSL, attiva WSL Mode.'
      : 'CLI "$binary" non trovata.';
}

AiCommand _wrap(List<String> argv, bool wslMode, String? workingDirectory) {
  if (!wslMode) return AiCommand(argv.first, argv.sublist(1));
  // A *login* shell is not optional: the CLIs live under paths that only the
  // shell's own startup files put on PATH (`wsl.exe -e claude` fails). See
  // ADR 0002.
  return AiCommand('wsl.exe', [
    if (workingDirectory != null) ...['--cd', workingDirectory],
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
    AiProvider.codex => _codexResult(stdout) ?? stdout,
    AiProvider.opencode => _opencodeResult(stdout) ?? stdout,
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

/// `codex exec --json` prints a JSONL event stream. The summary is the *last*
/// `agent_message` — earlier ones are the model thinking out loud. A line that
/// does not parse is a line we did not understand, not a reason to give up.
String? _codexResult(String stdout) {
  String? last;
  for (final line in const LineSplitter().convert(stdout)) {
    if (line.trim().isEmpty) continue;
    final event = _decodeMap(line);
    if (event == null) continue;
    // The message may sit at the top level or under `msg`, depending on the
    // codex version; both spell the payload the same way.
    final payload = event['msg'] is Map ? event['msg'] as Map : event;
    if (payload['type'] == 'agent_message' && payload['message'] is String) {
      last = payload['message'] as String;
    }
  }
  return last;
}

/// `opencode run --format json` prints one object; no event stream to walk.
String? _opencodeResult(String stdout) {
  final decoded = _decodeMap(stdout);
  if (decoded == null) return null;
  for (final key in const ['text', 'result', 'summary', 'output']) {
    if (decoded[key] is String) return decoded[key] as String;
  }
  return null;
}

Map<dynamic, dynamic>? _decodeMap(String source) {
  try {
    final decoded = jsonDecode(source.trim());
    return decoded is Map ? decoded : null;
  } on FormatException {
    return null;
  }
}
