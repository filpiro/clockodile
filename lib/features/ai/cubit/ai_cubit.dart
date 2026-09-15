import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/db/database.dart';
import '../ai_provider.dart';
import '../llama_config.dart';
import '../llama_installer.dart';
import '../llama_protocol.dart';
import '../llama_runtime.dart';

/// `sleeping` and `busy` do not exist: this UI cannot see them.
enum LocalAiStatus { notInstalled, installing, starting, ready, error }

class AiState {
  const AiState({
    this.enabled = false,
    this.status = LocalAiStatus.notInstalled,
    this.noFreePort = false,
    this.filesOnDisk = false,
    this.pendingBytes = 0,
    this.progress,
    this.installFailure,
  });

  /// `Settings.aiEnabled`. While false, [status] is not read.
  final bool enabled;
  final LocalAiStatus status;

  /// Only meaningful with [LocalAiStatus.error].
  final bool noFreePort;

  /// `<root>` exists — drives "Elimina modello".
  final bool filesOnDisk;

  /// Sum of the needed downloads, for the confirm and Aggiorna.
  final int pendingBytes;
  final InstallProgress? progress;
  final InstallFailure? installFailure;

  AiState copyWith({
    bool? enabled,
    LocalAiStatus? status,
    bool? noFreePort,
    bool? filesOnDisk,
    int? pendingBytes,
    InstallProgress? Function()? progress,
    InstallFailure? Function()? installFailure,
  }) => AiState(
    enabled: enabled ?? this.enabled,
    status: status ?? this.status,
    noFreePort: noFreePort ?? this.noFreePort,
    filesOnDisk: filesOnDisk ?? this.filesOnDisk,
    pendingBytes: pendingBytes ?? this.pendingBytes,
    progress: progress == null ? this.progress : progress(),
    installFailure: installFailure == null
        ? this.installFailure
        : installFailure(),
  );
}

/// The Local Model's lifecycle: install, start, restart once, stop.
class AiCubit extends Cubit<AiState> {
  AiCubit({
    required this.db,
    required this.paths,
    required this.installer,
    required this.runtime,
    required this.providerFor,
  }) : super(const AiState());

  final AppDatabase db;
  final LlamaPaths paths;
  final LlamaInstaller installer;
  final LlamaRuntime runtime;
  final AiProvider Function(int port) providerFor;

  AiProvider? _provider;
  Completer<void>? _cancelInstall;

  /// Bumped on every start and stop, so a late exit or a late start result
  /// from an abandoned server changes nothing.
  int _generation = 0;

  Future<void> init() async {
    if (!Platform.isWindows) return;
    final settings = await db.getSettings();
    _refreshDisk(enabled: settings.aiEnabled);
    if (!settings.aiEnabled) return;
    if (state.pendingBytes == 0) await _start();
  }

  Future<void> enable() => _install();
  Future<void> update() => _install();

  /// Annulla in the install modal.
  void cancelInstall() {
    if (_cancelInstall?.isCompleted == false) _cancelInstall!.complete();
  }

  /// Chiudi on a failed install.
  void dismissInstallFailure() =>
      emit(state.copyWith(installFailure: () => null));

  Future<void> _install() async {
    final needed = _needed();
    if (needed.isNotEmpty) {
      emit(
        state.copyWith(
          status: LocalAiStatus.installing,
          progress: () => null,
          installFailure: () => null,
        ),
      );
      await _stop();
      final cancel = _cancelInstall = Completer<void>();
      try {
        await installer.install(
          needed,
          onProgress: (p) => emit(state.copyWith(progress: () => p)),
          cancelled: cancel.future,
        );
      } on InstallCancelled {
        _refreshDisk(enabled: state.enabled);
        return;
      } on InstallException catch (err) {
        _refreshDisk(enabled: state.enabled, failure: err.failure);
        return;
      }
    }
    await db.saveSettings(const SettingsCompanion(aiEnabled: Value(true)));
    _refreshDisk(enabled: true);
    await _start();
  }

  Future<void> disable() async {
    await _stop();
    await db.saveSettings(const SettingsCompanion(aiEnabled: Value(false)));
    _refreshDisk(enabled: false);
  }

  Future<void> deleteFiles() async {
    await _stop();
    final root = Directory(paths.root);
    if (await root.exists()) await root.delete(recursive: true);
    await db.saveSettings(const SettingsCompanion(aiEnabled: Value(false)));
    _refreshDisk(enabled: false);
  }

  Future<void> retry() => _start();

  Future<void> shutdown() => _stop();

  Future<String> summarize(String text, {Future<void>? cancelled}) {
    final provider = _provider;
    if (state.status != LocalAiStatus.ready || provider == null) {
      return Future.error(const AiInvalidResponse());
    }
    // A request failure never changes status.
    return provider.summarize(text, cancelled: cancelled);
  }

  Future<void> _start() async {
    final generation = ++_generation;
    emit(state.copyWith(status: LocalAiStatus.starting, noFreePort: false));
    try {
      final port = await runtime.start();
      if (generation != _generation) return;
      _provider = providerFor(port);
      emit(state.copyWith(status: LocalAiStatus.ready));
      // One silent restart; renewed every time ready is reached, and a
      // restart that never reaches ready ends in error.
      runtime.exitCode?.then((_) {
        if (generation == _generation && !isClosed) _start();
      });
    } catch (err) {
      log('start failed: $err', name: 'clockodile.ai');
      if (generation != _generation || isClosed) return;
      emit(
        state.copyWith(
          status: LocalAiStatus.error,
          noFreePort: err is NoFreePort,
        ),
      );
    }
  }

  Future<void> _stop() {
    _generation++;
    _provider = null;
    return runtime.stop();
  }

  Set<AiDownload> _needed() => neededDownloads(
    marker: InstallMarker.decode(_readOrNull(paths.marker)),
    exeExists: File(paths.exe).existsSync(),
    modelExists: File(paths.model).existsSync(),
  );

  void _refreshDisk({required bool enabled, InstallFailure? failure}) {
    final pending = downloadBytes(_needed());
    emit(
      state.copyWith(
        enabled: enabled,
        status: LocalAiStatus.notInstalled,
        filesOnDisk: Directory(paths.root).existsSync(),
        pendingBytes: pending,
        progress: () => null,
        installFailure: () => failure,
      ),
    );
  }

  static String? _readOrNull(String path) {
    try {
      return File(path).readAsStringSync();
    } on FileSystemException {
      return null;
    }
  }
}
