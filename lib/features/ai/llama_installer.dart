import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'llama_config.dart';
import 'llama_protocol.dart';

/// An install that stopped for a reason the user is told about.
class InstallException implements Exception {
  const InstallException(this.failure);
  final InstallFailure failure;
}

/// The user pressed Annulla. No message.
class InstallCancelled implements Exception {
  const InstallCancelled();
}

/// Downloads, verifies and unpacks the pinned files. The server must already
/// be stopped: an unpack wipes `bin`.
class LlamaInstaller {
  LlamaInstaller(this.paths);

  final LlamaPaths paths;

  /// Throws [InstallException] or [InstallCancelled]. On either, every `.part`
  /// is gone and `installed.json` is untouched.
  Future<void> install(
    Set<AiDownload> needed, {
    required void Function(InstallProgress) onProgress,
    Future<void>? cancelled,
  }) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 30);
    var isCancelled = false;
    cancelled?.then((_) {
      isCancelled = true;
      client.close(force: true);
    });
    final parts = <File>[];
    try {
      await Directory(paths.root).create(recursive: true);
      // Runtime first.
      for (final d in AiDownload.values.where(needed.contains)) {
        switch (d) {
          case AiDownload.runtime:
            final part = File(paths.part(AiConfig.llamaAsset));
            parts.add(part);
            await _download(
              client,
              AiConfig.llamaUrl,
              AiConfig.llamaSha256,
              part,
              'llama.cpp',
              onProgress,
            );
            onProgress(const InstallProgress('Estrazione…', 0, null));
            await _unpack(part);
          case AiDownload.model:
            final part = File(paths.part(AiConfig.modelFile));
            parts.add(part);
            await _download(
              client,
              AiConfig.modelUrl,
              AiConfig.modelSha256,
              part,
              'Modello',
              onProgress,
            );
            final models = Directory(paths.models);
            if (await models.exists()) await models.delete(recursive: true);
            await models.create(recursive: true);
            await part.rename(paths.model);
        }
        if (isCancelled) throw const InstallCancelled();
      }
      await File(paths.marker).writeAsString(InstallMarker.current.encode());
    } catch (err) {
      if (isCancelled) throw const InstallCancelled();
      if (err is InstallException) rethrow;
      if (err is FileSystemException && err.osError?.errorCode == 112) {
        throw const InstallException(InstallFailure.diskFull);
      }
      if (err is! SocketException &&
          err is! HttpException &&
          err is! TimeoutException) {
        log('install failed: $err', name: 'clockodile.ai');
      }
      throw const InstallException(InstallFailure.network);
    } finally {
      client.close(force: true);
      for (final part in parts) {
        if (await part.exists()) await part.delete().catchError((_) => part);
      }
    }
  }

  /// Streams [url] into [part] and through SHA256 in the same pass.
  Future<void> _download(
    HttpClient client,
    String url,
    String sha,
    File part,
    String label,
    void Function(InstallProgress) onProgress,
  ) async {
    final response = await (await client.getUrl(Uri.parse(url))).close();
    if (response.statusCode != 200) {
      log('download $url: HTTP ${response.statusCode}', name: 'clockodile.ai');
      await response.drain<void>().catchError((_) {});
      throw const InstallException(InstallFailure.network);
    }
    final total = response.contentLength < 0 ? null : response.contentLength;
    Digest? digest;
    final hasher = sha256.startChunkedConversion(
      ChunkedConversionSink<Digest>.withCallback((d) => digest = d.single),
    );
    final sink = part.openWrite();
    var received = 0;
    var reported = 0;
    try {
      await for (final chunk in response.timeout(const Duration(seconds: 60))) {
        hasher.add(chunk);
        sink.add(chunk);
        received += chunk.length;
        // ponytail: one update per MB, enough for a bar and no emit storm.
        if (received - reported >= 1 << 20) {
          reported = received;
          onProgress(InstallProgress(label, received, total));
        }
      }
    } finally {
      await sink.close();
    }
    hasher.close();
    if ('$digest' != sha) {
      log('download $url: sha256 $digest', name: 'clockodile.ai');
      throw const InstallException(InstallFailure.checksum);
    }
  }

  /// The zip's files sit at its root. Anything short of a `llama-server.exe`
  /// afterwards means the archive is not what was pinned.
  Future<void> _unpack(File zip) async {
    final bin = Directory(paths.bin);
    if (await bin.exists()) await bin.delete(recursive: true);
    await bin.create(recursive: true);
    final systemRoot = Platform.environment['SystemRoot'] ?? r'C:\Windows';
    final result = await Process.run('$systemRoot\\System32\\tar.exe', [
      '-xf',
      zip.path,
      '-C',
      bin.path,
    ]);
    if (result.exitCode != 0 || !await File(paths.exe).exists()) {
      log(
        'tar exit ${result.exitCode}: ${result.stderr}',
        name: 'clockodile.ai',
      );
      throw const InstallException(InstallFailure.checksum);
    }
  }
}
