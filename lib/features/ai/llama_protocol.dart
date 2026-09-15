import 'dart:convert';

import 'ai_provider.dart';
import 'llama_config.dart';

/// Everything about the Local Model that can be decided without I/O: argv,
/// prompt, request body, response parsing, install state. No `Process`, no
/// `HttpClient`, no `File` — this file is the Local Model's test seam.

/// What `installed.json` records. Written last, so its presence means every
/// needed part of the last install succeeded.
class InstallMarker {
  const InstallMarker({required this.llamaTag, required this.modelSha256});

  final String llamaTag;
  final String modelSha256;

  static const current = InstallMarker(
    llamaTag: AiConfig.llamaTag,
    modelSha256: AiConfig.modelSha256,
  );

  String encode() =>
      jsonEncode({'llamaTag': llamaTag, 'modelSha256': modelSha256});

  /// Null on missing or malformed JSON; null means "no marker".
  static InstallMarker? decode(String? source) {
    if (source == null) return null;
    try {
      final json = jsonDecode(source);
      if (json is Map &&
          json['llamaTag'] is String &&
          json['modelSha256'] is String) {
        return InstallMarker(
          llamaTag: json['llamaTag'] as String,
          modelSha256: json['modelSha256'] as String,
        );
      }
    } on FormatException {
      // falls through
    }
    return null;
  }
}

/// One of the two pinned files.
enum AiDownload {
  runtime(AiConfig.llamaZipBytes),
  model(AiConfig.modelBytes);

  const AiDownload(this.bytes);
  final int bytes;
}

Set<AiDownload> neededDownloads({
  InstallMarker? marker,
  required bool exeExists,
  required bool modelExists,
}) {
  if (marker == null) return {AiDownload.runtime, AiDownload.model};
  return {
    if (marker.llamaTag != AiConfig.llamaTag || !exeExists) AiDownload.runtime,
    if (marker.modelSha256 != AiConfig.modelSha256 || !modelExists)
      AiDownload.model,
  };
}

/// Where an install is. [total] is null while extracting (or when the server
/// sent no `Content-Length`): an indeterminate bar.
class InstallProgress {
  const InstallProgress(this.label, this.received, this.total);
  final String label;
  final int received;
  final int? total;
}

enum InstallFailure { network, checksum, diskFull }

String installFailureMessage(
  InstallFailure failure,
  int neededBytes,
) => switch (failure) {
  InstallFailure.network =>
    'Download non riuscito. Controlla la connessione e riprova.',
  InstallFailure.checksum => 'File scaricato danneggiato. Riprova il download.',
  InstallFailure.diskFull =>
    'Spazio su disco insufficiente (servono circa ${formatBytes(neededBytes)}).',
};

int downloadBytes(Iterable<AiDownload> needed) =>
    needed.fold(0, (sum, d) => sum + d.bytes);

/// Decimal units, Italian comma: `1,3 GB` at or above 10⁹, whole `MB` below.
String formatBytes(int bytes) {
  if (bytes >= 1000000000) {
    return '${(bytes / 1e9).toStringAsFixed(1).replaceAll('.', ',')} GB';
  }
  return '${(bytes / 1e6).round()} MB';
}

List<String> buildLlamaArgs(String modelPath, int port) => [
  '-m',
  modelPath,
  '--host',
  AiConfig.host,
  '--port',
  '$port',
  // Alone enough to suppress thinking; without it every answer comes back
  // empty. No --chat-template-kwargs.
  '--reasoning',
  'off',
  '--parallel',
  '${AiConfig.parallel}',
  '--ctx-size',
  '${AiConfig.ctxSize}',
  '--sleep-idle-seconds',
  '${AiConfig.sleepIdleSeconds}',
];

/// Verbatim from ticket 07. More rules made the output worse: do not add any.
String buildLocalSummaryPrompt(String text) =>
    '''
Scrivi in italiano una nota di time-tracking brevissima, in stile telegrafico.

Massimo 15 parole.
Usa parole chiave e brevi frasi nome/azione.
Non serve una frase completa.
Tieni solo il lavoro essenziale richiesto.
Ometti saluti, riempitivi, esempi, citazioni e dettagli non essenziali.

Testo:
"""
$text
"""''';

String buildSummaryBody(String text) => jsonEncode({
  'model': AiConfig.modelFile,
  'messages': [
    {'role': 'user', 'content': buildLocalSummaryPrompt(text)},
  ],
  'temperature': AiConfig.temperature,
  'max_tokens': AiConfig.maxTokens,
  'cache_prompt': AiConfig.cachePrompt,
  'response_format': {
    'type': 'json_schema',
    'json_schema': {
      'name': 'summary',
      'strict': true,
      'schema': {
        'type': 'object',
        'properties': {
          'summary': {'type': 'string'},
        },
        'required': ['summary'],
        'additionalProperties': false,
      },
    },
  },
});

/// The trimmed summary, or throws [AiContextOverflow] / [AiInvalidResponse].
String parseLlamaSummary(int status, String body) {
  final json = _decode(body);
  if (status != 200) {
    final error = json?['error'];
    if (status == 400 &&
        error is Map &&
        error['type'] == 'exceed_context_size_error') {
      throw const AiContextOverflow();
    }
    throw const AiInvalidResponse();
  }
  final choices = json?['choices'];
  if (choices is! List || choices.isEmpty || choices.first is! Map) {
    throw const AiInvalidResponse();
  }
  final choice = choices.first as Map;
  // Before decoding: a truncated answer can still look half-valid.
  if (choice['finish_reason'] != 'stop') throw const AiInvalidResponse();
  final message = choice['message'];
  final content = message is Map ? message['content'] : null;
  if (content is! String || content.trim().isEmpty) {
    throw const AiInvalidResponse();
  }
  final summary = _decode(content)?['summary'];
  if (summary is! String || summary.trim().isEmpty) {
    throw const AiInvalidResponse();
  }
  return summary.trim();
}

/// Cold unless `/props` said plainly that the server is awake.
Duration timeoutForProps(String? body) => _decode(body)?['is_sleeping'] == false
    ? AiConfig.warmInferenceTimeout
    : AiConfig.coldInferenceTimeout;

/// True when a `tasklist /FO CSV /NH` line names our server, so a reused PID
/// belonging to anything else is never killed.
bool isOurProcess(String tasklistLine) =>
    tasklistLine.trim().split(',').first == '"llama-server.exe"';

Map<dynamic, dynamic>? _decode(String? source) {
  if (source == null) return null;
  try {
    final decoded = jsonDecode(source);
    return decoded is Map ? decoded : null;
  } on FormatException {
    return null;
  }
}
