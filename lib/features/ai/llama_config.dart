import 'dart:io' show Platform;

/// Every pin and knob of the Local Model. `const` only: no DB column, no UI,
/// no env override — bumped by hand in a Clockodile release (ADR 0003).
abstract final class AiConfig {
  // Runtime pin.
  static const llamaTag = 'b10900';
  static const llamaAsset = 'llama-b10900-bin-win-cpu-x64.zip';
  static const llamaUrl =
      'https://github.com/ggml-org/llama.cpp/releases/download/$llamaTag/$llamaAsset';
  static const llamaSha256 =
      '47f6fe584bc8a6510c00f40ed103ec43db66a52f4eee23126b8379c9028fd107';
  static const llamaZipBytes = 18423427;
  static const llamaUnpackedBytes = 46746909;

  // Model pin.
  static const modelRepo = 'ggml-org/Qwen3-1.7B-GGUF';
  static const modelRevision = 'daeb8e2d528a760970442092f6bf1e55c3b659eb';
  static const modelFile = 'Qwen3-1.7B-Q4_K_M.gguf';
  static const modelUrl =
      'https://huggingface.co/$modelRepo/resolve/$modelRevision/$modelFile';
  static const modelSha256 =
      'd2387ca2dbfee2ffabce7120d3770dadca0b293052bc2f0e138fdc940d9bc7b5';
  static const modelBytes = 1282439264;

  // Server.
  static const host = '127.0.0.1';
  static const portRangeStart = 18080;
  static const portRangeEnd = 18099; // inclusive, 20 ports
  static const ctxSize = 8192;
  static const parallel = 1;
  static const sleepIdleSeconds = 60;

  // Request.
  static const temperature = 0;
  static const maxTokens = 128;
  static const cachePrompt =
      false; // the configuration every timing was measured with

  // Timeouts — ~3x the measured headroom.
  static const startupTimeout = Duration(seconds: 120);
  static const coldInferenceTimeout = Duration(seconds: 90);
  static const warmInferenceTimeout = Duration(seconds: 30);
  static const healthPollInterval = Duration(milliseconds: 500);
  static const propsTimeout = Duration(seconds: 2);
}

/// The one seam mapping a root directory to every Local Model path. Tests pass
/// a temp directory.
class LlamaPaths {
  const LlamaPaths(this.root);

  /// `%LOCALAPPDATA%\Clockodile\ai`.
  factory LlamaPaths.production() => LlamaPaths(
    _join(Platform.environment['LOCALAPPDATA'] ?? '.', 'Clockodile\\ai'),
  );

  final String root;

  /// The whole release zip unpacked here; wiped before each unpack.
  String get bin => _join(root, 'bin');
  String get exe => _join(bin, 'llama-server.exe');
  String get models => _join(root, 'models');
  String get model => _join(models, AiConfig.modelFile);
  String get marker => _join(root, 'installed.json');

  /// In `root`, not `bin`, because an unpack wipes `bin`.
  String get pidFile => _join(root, 'llama-server.pid');
  String part(String name) => _join(root, '$name.part');

  static String _join(String a, String b) => '$a${Platform.pathSeparator}$b';
}
