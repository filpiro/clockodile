import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'ai_provider.dart';
import 'llama_config.dart';
import 'llama_protocol.dart';

/// A Note Summary from the Local Model over HTTP. Never logs the text.
class LlamaCppProvider implements AiProvider {
  LlamaCppProvider(this.port);

  final int port;

  @override
  Future<String> summarize(String text, {Future<void>? cancelled}) async {
    final client = HttpClient();
    var isCancelled = false;
    cancelled?.then((_) {
      isCancelled = true;
      client.close(force: true);
    });
    try {
      final timeout = timeoutForProps(await _props(client));
      if (isCancelled) throw const AiCancelled();
      final watch = Stopwatch()..start();
      final (status, body) = await _post(
        client,
        buildSummaryBody(text),
      ).timeout(timeout);
      log(
        'HTTP $status in ${watch.elapsedMilliseconds} ms, ${_timings(body)}',
        name: 'clockodile.ai',
      );
      try {
        final summary = parseLlamaSummary(status, body);
        if (isCancelled) throw const AiCancelled();
        return summary;
      } on AiFailure {
        log('failed response: $body', name: 'clockodile.ai');
        rethrow;
      }
    } catch (err) {
      if (isCancelled) throw const AiCancelled();
      if (err is AiFailure) rethrow;
      if (err is TimeoutException) throw const AiTimeout();
      log('request failed: $err', name: 'clockodile.ai');
      throw const AiInvalidResponse();
    } finally {
      client.close(force: true);
    }
  }

  /// `/props` neither wakes the server nor resets its idle timer. Null on any
  /// failure, which counts as cold.
  Future<String?> _props(HttpClient client) async {
    try {
      final response = await (await client.get(
        AiConfig.host,
        port,
        '/props',
      )).close().timeout(AiConfig.propsTimeout);
      return await response
          .transform(utf8.decoder)
          .join()
          .timeout(AiConfig.propsTimeout);
    } catch (_) {
      return null;
    }
  }

  Future<(int, String)> _post(HttpClient client, String body) async {
    final request = await client.post(
      AiConfig.host,
      port,
      '/v1/chat/completions',
    );
    request.headers.contentType = ContentType.json;
    request.add(utf8.encode(body));
    final response = await request.close();
    return (response.statusCode, await response.transform(utf8.decoder).join());
  }

  static String _timings(String body) {
    try {
      final json = jsonDecode(body) as Map;
      final timings = json['timings'] as Map?;
      final usage = json['usage'] as Map?;
      return 'prompt_ms=${timings?['prompt_ms']} '
          'predicted_ms=${timings?['predicted_ms']} '
          'cached_tokens=${(usage?['prompt_tokens_details'] as Map?)?['cached_tokens']}';
    } catch (_) {
      return 'no timings';
    }
  }
}
