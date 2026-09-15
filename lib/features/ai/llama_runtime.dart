import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'llama_config.dart';
import 'llama_protocol.dart';

/// Every port in the range is taken.
class NoFreePort implements Exception {
  const NoFreePort();
}

/// The server exited, could not spawn, or never became healthy in time.
class StartFailed implements Exception {
  const StartFailed(this.reason);
  final String reason;

  @override
  String toString() => 'StartFailed: $reason';
}

/// Owns the one `llama-server` process this app spawns.
class LlamaRuntime {
  LlamaRuntime(this.paths);

  final LlamaPaths paths;
  Process? _process;

  /// Completes when the running server exits; null when none runs.
  Future<int>? get exitCode => _process?.exitCode;

  /// The port the healthy server listens on.
  Future<int> start() async {
    await stop();
    await _killOrphan();
    final port = await _freePort();
    log('port $port', name: 'clockodile.ai');

    final Process process;
    try {
      process = await Process.start(
        paths.exe,
        buildLlamaArgs(paths.model, port),
      );
    } on ProcessException catch (err) {
      throw StartFailed('$err');
    }
    _process = process;
    await File(paths.pidFile).writeAsString('${process.pid}');
    process.stdout.drain<void>();
    final tail = <String>[];
    process.stderr
        .transform(const Utf8Decoder(allowMalformed: true))
        .transform(const LineSplitter())
        .listen((line) {
          tail.add(line);
          if (tail.length > 20) tail.removeAt(0);
        });
    var exited = false;
    process.exitCode.then((code) {
      exited = true;
      log(
        'llama-server exit $code:\n${tail.join('\n')}',
        name: 'clockodile.ai',
      );
    });

    final deadline = DateTime.now().add(AiConfig.startupTimeout);
    final client = HttpClient()
      ..connectionTimeout = AiConfig.healthPollInterval * 4;
    try {
      while (true) {
        if (exited) {
          await stop();
          throw const StartFailed('exited before healthy');
        }
        if (DateTime.now().isAfter(deadline)) {
          await stop();
          throw const StartFailed('startup timeout');
        }
        try {
          final response = await (await client.get(
            AiConfig.host,
            port,
            '/health',
          )).close();
          await response.drain<void>();
          // 503 means loading; /health is only a startup gate — it says ok
          // while sleeping too.
          if (response.statusCode == 200) return port;
        } on SocketException {
          // not listening yet
        } on HttpException {
          // same
        }
        await Future<void>.delayed(AiConfig.healthPollInterval);
      }
    } finally {
      client.close(force: true);
    }
  }

  /// Safe at any time.
  Future<void> stop() async {
    final process = _process;
    _process = null;
    // No process of ours: a leftover PID file is the orphan check's to read.
    if (process == null) return;
    process.kill();
    await process.exitCode;
    final pid = File(paths.pidFile);
    if (await pid.exists()) await pid.delete().catchError((_) => pid);
  }

  /// A PID file left by a crash. Killed only when the PID still names
  /// `llama-server.exe`: Windows reuses PIDs. Never searched for by name.
  Future<void> _killOrphan() async {
    final file = File(paths.pidFile);
    if (!await file.exists()) return;
    try {
      final pid = int.tryParse((await file.readAsString()).trim());
      if (pid != null) {
        final result = await Process.run('tasklist', [
          '/FI',
          'PID eq $pid',
          '/FO',
          'CSV',
          '/NH',
        ]);
        if (isOurProcess('${result.stdout}')) {
          Process.killPid(pid);
          log('killed orphan llama-server $pid', name: 'clockodile.ai');
        }
      }
    } catch (err) {
      log('orphan check failed: $err', name: 'clockodile.ai');
    }
    await file.delete().catchError((_) => file);
  }

  /// Same technique as the single-instance lock in `main.dart`.
  static Future<int> _freePort() async {
    for (var p = AiConfig.portRangeStart; p <= AiConfig.portRangeEnd; p++) {
      try {
        final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, p);
        await socket.close();
        return p;
      } on SocketException {
        // taken
      }
    }
    throw const NoFreePort();
  }
}
