import 'package:clockodile/data/db/database.dart';
import 'package:clockodile/features/ai/summary_command.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AiCommand claude({
    String model = 'sonnet',
    String effort = 'high',
    bool wsl = false,
  }) => buildAiCommand(
    provider: AiProvider.claudeCode,
    model: model,
    effort: effort,
    wslMode: wsl,
    workingDirectory: '/tmp/x',
  );

  group('Claude Code argument list', () {
    for (final model in ['sonnet', 'opus']) {
      for (final effort in ['low', 'medium', 'high']) {
        test('$model + $effort', () {
          final cmd = claude(model: model, effort: effort);

          expect(cmd.executable, 'claude');
          expect(cmd.arguments, [
            '-p',
            '--output-format',
            'json',
            '--model',
            model,
            '--effort',
            effort,
          ]);
        });
      }
    }

    test('carries no prompt argument — the prompt goes over stdin', () {
      expect(claude().arguments, isNot(contains(contains('Summarize'))));
    });
  });

  group('WSL mode', () {
    test('runs through wsl.exe --cd <dir> -e bash -lc <one string>', () {
      final cmd = claude(wsl: true);

      expect(cmd.executable, 'wsl.exe');
      expect(cmd.arguments.take(5), ['--cd', '/tmp/x', '-e', 'bash', '-lc']);
      expect(cmd.arguments.length, 6); // exactly one command string
      expect(
        cmd.arguments.last,
        "'claude' '-p' '--output-format' 'json' '--model' 'sonnet' "
        "'--effort' 'high'",
      );
    });

    test('no shell is involved when WSL is off', () {
      final cmd = claude();

      expect(cmd.executable, isNot(anyOf('wsl.exe', 'bash', 'sh')));
      expect(cmd.arguments, isNot(contains('-lc')));
    });

    test("a single quote is escaped as '\\''", () {
      final cmd = buildAiCommand(
        provider: AiProvider.claudeCode,
        model: "it's",
        effort: 'high',
        wslMode: true,
        workingDirectory: '/tmp/x',
      );

      expect(cmd.arguments.last, contains(r"'it'\''s'"));
    });

    test('a value carrying `; rm -rf ~` cannot terminate its argument', () {
      final cmd = buildAiCommand(
        provider: AiProvider.claudeCode,
        model: "x'; rm -rf ~; echo '",
        effort: 'high',
        wslMode: true,
        workingDirectory: '/tmp/x',
      );

      // Every quote the value carries is neutralised, so the whole value stays
      // one argument: no bare `;` ever reaches the shell as syntax.
      final command = cmd.arguments.last;
      expect(command, contains(r"'x'\''; rm -rf ~; echo '\'''"));
      expect(command, isNot(contains("; rm -rf ~; echo ' ")));
    });
  });

  group('parsing Claude output', () {
    test("takes the JSON object's result field", () {
      final out = parseAiResult(
        AiProvider.claudeCode,
        '{"type":"result","result":"Cliente chiede sconto sul rinnovo.",'
        '"cost_usd":0.01}',
      );

      expect(out, 'Cliente chiede sconto sul rinnovo.');
    });

    test('trims surrounding whitespace', () {
      expect(
        parseAiResult(AiProvider.claudeCode, '{"result":"  ciao  "}'),
        'ciao',
      );
    });

    for (final raw in ['', '   \n\t ', '{"result":""}', '{"result":"  "}']) {
      test('nothing usable from ${raw.isEmpty ? '<empty>' : '"$raw"'}', () {
        expect(parseAiResult(AiProvider.claudeCode, raw), isNull);
      });
    }

    test('unparseable stdout is nothing usable, not an empty string', () {
      expect(parseAiResult(AiProvider.claudeCode, 'not json at all'), isNull);
      expect(parseAiResult(AiProvider.claudeCode, '{"no_result":1}'), isNull);
    });
  });

  group('the prompt', () {
    test('carries the note verbatim, quotes and backticks included', () {
      const email = 'Ciao,\n"urgente" — vedi `deploy.sh`\nGrazie';

      expect(buildSummaryPrompt(email), contains(email));
    });
  });

  group('word gate', () {
    test('ten whitespace-separated words is enough, nine is not', () {
      expect(hasEnoughWordsForSummary('a b c d e f g h i'), isFalse);
      expect(hasEnoughWordsForSummary('a b c d e f g h i j'), isTrue);
    });

    test('runs of whitespace do not count as words', () {
      expect(hasEnoughWordsForSummary('  \n a \t\t b \n\n '), isFalse);
      expect(hasEnoughWordsForSummary(''), isFalse);
    });
  });
}
