import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'summary_command.dart';

/// The impure half of the AI module: spawn, write stdin, collect output, kill
/// on time. It decides nothing — what to run comes from [buildAiCommand] and
/// what the output meant comes from [parseAiResult].

/// What the CLI did. A non-zero [exitCode] is a failure whatever is in
/// [stdout]; [stderr] is surfaced to the user one line at a time.
typedef AiOutput = ({int exitCode, String stdout, String stderr});

const _timeout = Duration(seconds: 60);

/// One generation attempt, cancellable because the user may leave the page
/// while an agentic CLI is still thinking.
class AiRun {
  Process? _process;
  bool _cancelled = false;

  /// Runs [command] with [prompt] on its stdin, in a fresh temporary directory
  /// — never the app's own, since these CLIs can read whatever they can reach.
  Future<AiOutput> run(
    AiCommand Function(String workingDirectory) command,
    String prompt,
  ) async {
    final dir = await Directory.systemTemp.createTemp('clockodile_ai');
    try {
      final cmd = command(dir.path);
      final process = await Process.start(
        cmd.executable,
        cmd.arguments,
        workingDirectory: dir.path,
      );
      _process = process;
      if (_cancelled) process.kill();

      process.stdin.write(prompt);
      // Closed so the CLI sees end-of-input and stops waiting for more.
      await process.stdin.close();

      final stdout = process.stdout.transform(utf8.decoder).join();
      final stderr = process.stderr.transform(utf8.decoder).join();
      final exitCode = await process.exitCode.timeout(
        _timeout,
        onTimeout: () {
          process.kill();
          return -1;
        },
      );
      // Both are drained even on a timeout: the process is dead by now and a
      // dangling stream would outlive the run.
      final out = await stdout;
      final err = await stderr;
      return (
        exitCode: exitCode,
        stdout: out,
        stderr: exitCode == -1
            ? 'Tempo scaduto dopo ${_timeout.inSeconds} secondi.'
            : err,
      );
    } finally {
      _process = null;
      await dir.delete(recursive: true).catchError((_) => dir);
    }
  }

  /// Kills the CLI if it is still running. Safe before, during and after.
  void cancel() {
    _cancelled = true;
    _process?.kill();
  }
}
