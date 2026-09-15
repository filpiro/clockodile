import 'dart:async';
import 'dart:io';

import 'package:clockodile/data/db/database.dart';
import 'package:clockodile/features/ai/ai_provider.dart';
import 'package:clockodile/features/ai/cubit/ai_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clockodile/features/ai/llama_config.dart';
import 'package:clockodile/features/ai/llama_installer.dart';
import 'package:clockodile/features/ai/llama_protocol.dart';
import 'package:clockodile/features/ai/llama_runtime.dart';

/// Hand-written stand-ins for the Local Model's impure half. Nothing here
/// spawns or downloads.

class FakeInstaller implements LlamaInstaller {
  FakeInstaller(this.paths);

  @override
  final LlamaPaths paths;

  /// Thrown instead of installing, when set.
  Object? error;
  int calls = 0;

  @override
  Future<void> install(
    Set<AiDownload> needed, {
    required void Function(InstallProgress) onProgress,
    Future<void>? cancelled,
  }) async {
    calls++;
    if (error != null) throw error!;
    writeInstalledFiles(paths);
  }
}

class FakeRuntime implements LlamaRuntime {
  @override
  LlamaPaths get paths => throw UnimplementedError();

  /// Each start pops the next outcome: a port, a `Future<int>` port (never
  /// completing it keeps the server starting), or an exception to throw.
  final outcomes = <Object>[];
  int starts = 0;
  int stops = 0;
  Completer<int>? _exit;

  @override
  Future<int>? get exitCode => _exit?.future;

  @override
  Future<int> start() async {
    starts++;
    var outcome = outcomes.isEmpty ? 18080 : outcomes.removeAt(0);
    if (outcome is Future<int>) outcome = await outcome;
    if (outcome is! int) throw outcome;
    _exit = Completer<int>();
    return outcome;
  }

  @override
  Future<void> stop() async {
    stops++;
    _exit = null;
  }

  /// The server dies on its own.
  void crash() {
    final exit = _exit;
    _exit = null;
    exit?.complete(1);
  }
}

class FakeProvider implements AiProvider {
  FakeProvider(this.port);
  final int port;

  @override
  Future<String> summarize(String text, {Future<void>? cancelled}) async =>
      'riassunto $port';
}

/// An [AiCubit] on fakes and a fresh temp root, removed after the test.
AiCubit fakeAiCubit(AppDatabase db, {FakeRuntime? runtime}) {
  final tmp = Directory.systemTemp.createTempSync('clockodile_ai_test');
  addTearDown(() => tmp.deleteSync(recursive: true));
  final paths = LlamaPaths('${tmp.path}${Platform.pathSeparator}ai');
  return AiCubit(
    db: db,
    paths: paths,
    installer: FakeInstaller(paths),
    runtime: runtime ?? FakeRuntime(),
    providerFor: FakeProvider.new,
  );
}

void writeInstalledFiles(LlamaPaths paths) {
  File(paths.exe).createSync(recursive: true);
  File(paths.model).createSync(recursive: true);
  File(paths.marker).writeAsStringSync(InstallMarker.current.encode());
}
