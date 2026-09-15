import 'package:clockodile/data/db/database.dart';
import 'package:clockodile/features/ai/summary_command.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AiCommand claude({
    String model = 'sonnet',
    String effort = 'high',
    bool wsl = false,
  }) => buildAiCommand(
    provider: AiProviderKind.claudeCode,
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
        provider: AiProviderKind.claudeCode,
        model: "it's",
        effort: 'high',
        wslMode: true,
        workingDirectory: '/tmp/x',
      );

      expect(cmd.arguments.last, contains(r"'it'\''s'"));
    });

    test('a value carrying `; rm -rf ~` cannot terminate its argument', () {
      final cmd = buildAiCommand(
        provider: AiProviderKind.claudeCode,
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
        AiProviderKind.claudeCode,
        '{"type":"result","result":"Cliente chiede sconto sul rinnovo.",'
        '"cost_usd":0.01}',
      );

      expect(out, 'Cliente chiede sconto sul rinnovo.');
    });

    test('trims surrounding whitespace', () {
      expect(
        parseAiResult(AiProviderKind.claudeCode, '{"result":"  ciao  "}'),
        'ciao',
      );
    });

    for (final raw in ['', '   \n\t ', '{"result":""}', '{"result":"  "}']) {
      test('nothing usable from ${raw.isEmpty ? '<empty>' : '"$raw"'}', () {
        expect(parseAiResult(AiProviderKind.claudeCode, raw), isNull);
      });
    }

    test('unparseable stdout is nothing usable, not an empty string', () {
      expect(
        parseAiResult(AiProviderKind.claudeCode, 'not json at all'),
        isNull,
      );
      expect(
        parseAiResult(AiProviderKind.claudeCode, '{"no_result":1}'),
        isNull,
      );
    });
  });

  group('Codex argument list', () {
    AiCommand codex({String model = 'gpt-5', String effort = 'high'}) =>
        buildAiCommand(
          provider: AiProviderKind.codex,
          model: model,
          effort: effort,
          wslMode: false,
          workingDirectory: '/tmp/x',
        );

    test('model and effort', () {
      final cmd = codex();

      expect(cmd.executable, 'codex');
      expect(cmd.arguments, [
        'exec',
        '--json',
        '-m',
        'gpt-5',
        '-c',
        'model_reasoning_effort=high',
      ]);
    });

    test('empty effort omits the override entirely', () {
      expect(codex(effort: '').arguments, ['exec', '--json', '-m', 'gpt-5']);
    });

    test('empty model omits -m entirely', () {
      expect(codex(model: '').arguments, [
        'exec',
        '--json',
        '-c',
        'model_reasoning_effort=high',
      ]);
    });
  });

  group('OpenCode argument list', () {
    AiCommand opencode({
      String model = 'anthropic/claude-sonnet-4',
      String effort = 'high',
    }) => buildAiCommand(
      provider: AiProviderKind.opencode,
      model: model,
      effort: effort,
      wslMode: false,
      workingDirectory: '/tmp/x',
    );

    test('model and effort', () {
      final cmd = opencode();

      expect(cmd.executable, 'opencode');
      expect(cmd.arguments, [
        'run',
        '--format',
        'json',
        '-m',
        'anthropic/claude-sonnet-4',
        '--variant',
        'high',
      ]);
    });

    test('empty effort omits --variant', () {
      expect(opencode(effort: '').arguments, isNot(contains('--variant')));
    });

    test('empty model omits -m', () {
      expect(opencode(model: '').arguments, [
        'run',
        '--format',
        'json',
        '--variant',
        'high',
      ]);
    });
  });

  group('Codex stdout', () {
    test('takes the last agent_message, not the first', () {
      const stream =
          '{"msg":{"type":"agent_message","message":"primo"}}\n'
          '{"msg":{"type":"token_count","input":12}}\n'
          '{"msg":{"type":"agent_message","message":"ultimo"}}\n';

      expect(parseAiResult(AiProviderKind.codex, stream), 'ultimo');
    });

    test('reads a top-level event as well as a nested one', () {
      expect(
        parseAiResult(
          AiProviderKind.codex,
          '{"type":"agent_message","message":"piatto"}',
        ),
        'piatto',
      );
    });

    test('skips malformed lines instead of aborting the parse', () {
      const stream =
          'not json\n'
          '{"msg":{"type":"agent_message","message":"buona"}}\n'
          '{"broken\n';

      expect(parseAiResult(AiProviderKind.codex, stream), 'buona');
    });

    test('no parseable event falls back to the trimmed raw stdout', () {
      expect(parseAiResult(AiProviderKind.codex, '  rumore  \n'), 'rumore');
    });

    test('nothing at all is nothing usable', () {
      expect(parseAiResult(AiProviderKind.codex, '   \n '), isNull);
    });
  });

  group('OpenCode stdout', () {
    test('reads the object text', () {
      expect(
        parseAiResult(AiProviderKind.opencode, '{"text":"sintesi"}'),
        'sintesi',
      );
    });

    test('unparseable output falls back to the trimmed raw stdout', () {
      expect(parseAiResult(AiProviderKind.opencode, ' sintesi \n'), 'sintesi');
    });

    test('empty output is nothing usable', () {
      expect(parseAiResult(AiProviderKind.opencode, '{"text":"  "}'), isNull);
      expect(parseAiResult(AiProviderKind.opencode, ''), isNull);
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

  group('version command', () {
    test('runs the bare binary with --version outside WSL', () {
      final cmd = buildVersionCommand(
        provider: AiProviderKind.codex,
        wslMode: false,
      );

      expect(cmd.executable, 'codex');
      expect(cmd.arguments, ['--version']);
    });

    test('goes through a login shell under WSL', () {
      final cmd = buildVersionCommand(
        provider: AiProviderKind.opencode,
        wslMode: true,
      );

      expect(cmd.executable, 'wsl.exe');
      expect(cmd.arguments, ['-e', 'bash', '-lc', "'opencode' '--version'"]);
    });
  });

  group('missing CLI message', () {
    test('names the binary', () {
      expect(
        cliMissingMessage(
          provider: AiProviderKind.claudeCode,
          suggestWsl: false,
        ),
        contains('claude'),
      );
    });

    test('points at WSL Mode when it could be the cause', () {
      expect(
        cliMissingMessage(
          provider: AiProviderKind.claudeCode,
          suggestWsl: true,
        ),
        contains('WSL'),
      );
      expect(
        cliMissingMessage(
          provider: AiProviderKind.claudeCode,
          suggestWsl: false,
        ),
        isNot(contains('WSL')),
      );
    });
  });
}
