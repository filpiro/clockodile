import 'dart:convert';
import 'dart:io';

import 'package:clockodile/features/ai/ai_provider.dart';
import 'package:clockodile/features/ai/llama_config.dart';
import 'package:clockodile/features/ai/llama_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

String fixture(String name) =>
    File('docs/llama.cpp/fixtures/$name').readAsStringSync();

void main() {
  group('buildLlamaArgs', () {
    test('is exactly the verified argv', () {
      expect(buildLlamaArgs(r'C:\m.gguf', 18081), [
        '-m',
        r'C:\m.gguf',
        '--host',
        '127.0.0.1',
        '--port',
        '18081',
        '--reasoning',
        'off',
        '--parallel',
        '1',
        '--ctx-size',
        '8192',
        '--sleep-idle-seconds',
        '60',
      ]);
    });

    test('never passes chat template kwargs', () {
      expect(buildLlamaArgs('m', 1), isNot(contains('--chat-template-kwargs')));
    });
  });

  test('the prompt substitutes the input verbatim', () {
    const input = 'a "quote" `tick`\nnew line';
    expect(
      buildLocalSummaryPrompt(input),
      'Scrivi in italiano una nota di time-tracking brevissima, in stile telegrafico.\n'
      '\n'
      'Massimo 15 parole.\n'
      'Usa parole chiave e brevi frasi nome/azione.\n'
      'Non serve una frase completa.\n'
      'Tieni solo il lavoro essenziale richiesto.\n'
      'Ometti saluti, riempitivi, esempi, citazioni e dettagli non essenziali.\n'
      '\n'
      'Testo:\n'
      '"""\n'
      '$input\n'
      '"""',
    );
  });

  test('the body matches the verified request, prompt and model aside', () {
    Map<String, dynamic> strip(Map<String, dynamic> m) => m
      ..remove('model')
      ..['messages'][0].remove('content');
    final body = jsonDecode(buildSummaryBody('x')) as Map<String, dynamic>;
    expect(body['model'], AiConfig.modelFile);
    expect(body['messages'][0]['content'], buildLocalSummaryPrompt('x'));
    expect(
      strip(body),
      strip(jsonDecode(fixture('summary.constrained.request.json'))),
    );
  });

  group('parseLlamaSummary', () {
    test('a constrained answer gives its summary', () {
      expect(
        parseLlamaSummary(
          200,
          fixture('summary.constrained.pinned-reasoning-off.response.json'),
        ),
        startsWith('add free shipping'),
      );
    });

    for (final name in [
      'summary.constrained.localfile-no-flag.response.json',
      'summary.truncated.pinned-reasoning-off.response.json',
      'summary.unconstrained.pinned-reasoning-off.response.json',
    ]) {
      test('$name is invalid', () {
        expect(
          () => parseLlamaSummary(200, fixture(name)),
          throwsA(isA<AiInvalidResponse>()),
        );
      });
    }

    test('a context overflow is recognised by its type', () {
      expect(
        () => parseLlamaSummary(
          400,
          '{"error":{"code":400,"type":"exceed_context_size_error",'
          '"message":"request (9000 tokens) exceeds the available context size (8192 tokens)",'
          '"n_prompt_tokens":9000,"n_ctx":8192}}',
        ),
        throwsA(isA<AiContextOverflow>()),
      );
    });

    test('any other error status is invalid', () {
      expect(
        () => parseLlamaSummary(
          400,
          '{"error":{"code":400,"type":"invalid_request_error"}}',
        ),
        throwsA(isA<AiInvalidResponse>()),
      );
      expect(
        () => parseLlamaSummary(500, 'boom'),
        throwsA(isA<AiInvalidResponse>()),
      );
    });

    test('a blank summary is invalid', () {
      final body = jsonEncode({
        'choices': [
          {
            'finish_reason': 'stop',
            'message': {'content': '{"summary": "   "}'},
          },
        ],
      });
      expect(
        () => parseLlamaSummary(200, body),
        throwsA(isA<AiInvalidResponse>()),
      );
    });
  });

  test('timeoutForProps is warm only when the server says it is awake', () {
    expect(
      timeoutForProps('{"is_sleeping":true}'),
      AiConfig.coldInferenceTimeout,
    );
    expect(
      timeoutForProps('{"is_sleeping":false}'),
      AiConfig.warmInferenceTimeout,
    );
    expect(timeoutForProps(null), AiConfig.coldInferenceTimeout);
    expect(timeoutForProps('nope'), AiConfig.coldInferenceTimeout);
  });

  group('neededDownloads', () {
    const current = InstallMarker.current;
    Set<AiDownload> needed(
      InstallMarker? marker, {
      bool exe = true,
      bool model = true,
    }) => neededDownloads(marker: marker, exeExists: exe, modelExists: model);

    test('no marker needs both', () {
      expect(needed(null), {AiDownload.runtime, AiDownload.model});
    });
    test('everything matching needs nothing', () {
      expect(needed(current), isEmpty);
    });
    test('a bumped tag needs the runtime only', () {
      expect(
        needed(
          InstallMarker(llamaTag: 'old', modelSha256: current.modelSha256),
        ),
        {AiDownload.runtime},
      );
    });
    test('a bumped sha needs the model only', () {
      expect(
        needed(InstallMarker(llamaTag: current.llamaTag, modelSha256: 'old')),
        {AiDownload.model},
      );
    });
    test('a missing exe needs the runtime', () {
      expect(needed(current, exe: false), {AiDownload.runtime});
    });
    test('a missing model needs the model', () {
      expect(needed(current, model: false), {AiDownload.model});
    });
  });

  test('InstallMarker round-trips, and malformed JSON is no marker', () {
    final back = InstallMarker.decode(InstallMarker.current.encode())!;
    expect(back.llamaTag, AiConfig.llamaTag);
    expect(back.modelSha256, AiConfig.modelSha256);
    expect(InstallMarker.decode('{"llamaTag":'), isNull);
    expect(InstallMarker.decode('[]'), isNull);
    expect(InstallMarker.decode(null), isNull);
  });

  test('formatBytes', () {
    expect(formatBytes(18423427), '18 MB');
    expect(formatBytes(1282439264), '1,3 GB');
    expect(formatBytes(1300862691), '1,3 GB');
    expect(formatBytes(downloadBytes(AiDownload.values)), '1,3 GB');
  });

  test('isOurProcess', () {
    expect(
      isOurProcess('"llama-server.exe","1234","Console","1","1.000 K"'),
      isTrue,
    );
    expect(
      isOurProcess('"notepad.exe","1234","Console","1","1.000 K"'),
      isFalse,
    );
    expect(
      isOurProcess(
        'INFO: No tasks are running which match the specified criteria.',
      ),
      isFalse,
    );
  });
}
