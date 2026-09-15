import '../../data/db/database.dart';
import 'ai_provider.dart';
import 'summary_command.dart';
import 'summary_runner.dart';

/// A Note Summary from a coding-agent CLI (ADR 0002). Hidden since the Local
/// Model (ADR 0003): nothing constructs it, but a later unhide needs nothing
/// else.
class CliAiProvider implements AiProvider {
  CliAiProvider(this.kind, this.settings);

  final AiProviderKind kind;
  final Setting settings;

  @override
  Future<String> summarize(String text, {Future<void>? cancelled}) async {
    final (model, effort) = switch (kind) {
      AiProviderKind.claudeCode => (
        settings.aiClaudeModel,
        settings.aiClaudeEffort,
      ),
      AiProviderKind.codex => (settings.aiCodexModel, settings.aiCodexEffort),
      AiProviderKind.opencode => (
        settings.aiOpencodeModel,
        settings.aiOpencodeEffort,
      ),
    };
    final run = AiRun();
    var isCancelled = false;
    cancelled?.then((_) {
      isCancelled = true;
      run.cancel();
    });
    String? failure;
    String? summary;
    try {
      final out = await run.run(
        (dir) => buildAiCommand(
          provider: kind,
          model: model,
          effort: effort,
          wslMode: settings.aiWslMode,
          workingDirectory: dir,
        ),
        buildSummaryPrompt(text),
      );
      summary = out.exitCode == 0 ? parseAiResult(kind, out.stdout) : null;
      // A non-zero exit, a timeout and a blank result are the same outcome.
      if (summary == null) {
        failure = _firstLine(out.stderr) ?? 'Nessun riassunto prodotto.';
      }
    } catch (err) {
      failure = _firstLine('$err') ?? 'Generazione fallita.';
    }
    if (isCancelled) throw const AiCancelled();
    if (summary == null) throw AiCliFailure(failure!);
    return summary;
  }

  static String? _firstLine(String text) {
    final line = text.trim().split('\n').first.trim();
    return line.isEmpty ? null : line;
  }
}
