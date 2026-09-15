import 'dart:io';

import 'package:clockodile/data/db/database.dart';
import 'package:clockodile/features/ai/ai_provider.dart';
import 'package:clockodile/features/ai/cubit/ai_cubit.dart';
import 'package:clockodile/features/ai/llama_config.dart';
import 'package:clockodile/features/ai/llama_installer.dart';
import 'package:clockodile/features/ai/llama_protocol.dart';
import 'package:clockodile/features/ai/llama_runtime.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ai_fakes.dart';

void main() {
  late AppDatabase db;
  late Directory tmp;
  late LlamaPaths paths;
  late FakeInstaller installer;
  late FakeRuntime runtime;
  late AiCubit cubit;
  late List<LocalAiStatus> seen;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    tmp = Directory.systemTemp.createTempSync('clockodile_ai_test');
    paths = LlamaPaths('${tmp.path}${Platform.pathSeparator}ai');
    installer = FakeInstaller(paths);
    runtime = FakeRuntime();
    cubit = AiCubit(
      db: db,
      paths: paths,
      installer: installer,
      runtime: runtime,
      providerFor: FakeProvider.new,
    );
    seen = [];
    cubit.stream.listen((s) => seen.add(s.status));
  });

  tearDown(() async {
    await cubit.close();
    await db.close();
    tmp.deleteSync(recursive: true);
  });

  Future<void> enabledInDb() =>
      db.saveSettings(const SettingsCompanion(aiEnabled: Value(true)));

  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('enabled and installed goes starting, then ready', () async {
    await enabledInDb();
    writeInstalledFiles(paths);

    await cubit.init();
    await settle();

    expect(
      seen,
      containsAllInOrder([LocalAiStatus.starting, LocalAiStatus.ready]),
    );
    expect(cubit.state.status, LocalAiStatus.ready);
  });

  test('enabled without a marker is notInstalled with the full size', () async {
    await enabledInDb();

    await cubit.init();

    expect(cubit.state.status, LocalAiStatus.notInstalled);
    expect(cubit.state.pendingBytes, 1300862691);
    expect(runtime.starts, 0);
  });

  test('a failed start is an error; no free port says so', () async {
    await enabledInDb();
    writeInstalledFiles(paths);
    runtime.outcomes.add(const StartFailed('boom'));
    await cubit.init();
    expect(cubit.state.status, LocalAiStatus.error);
    expect(cubit.state.noFreePort, isFalse);

    runtime.outcomes.add(const NoFreePort());
    await cubit.retry();
    expect(cubit.state.status, LocalAiStatus.error);
    expect(cubit.state.noFreePort, isTrue);
  });

  test(
    'an exit while ready restarts once; dying before ready is an error',
    () async {
      await enabledInDb();
      writeInstalledFiles(paths);
      await cubit.init();
      await settle();
      seen.clear();

      runtime.crash();
      await settle();
      expect(seen, [LocalAiStatus.starting, LocalAiStatus.ready]);

      runtime.outcomes.add(const StartFailed('died again'));
      runtime.crash();
      await settle();
      expect(cubit.state.status, LocalAiStatus.error);
    },
  );

  test('enable persists and ends ready', () async {
    await cubit.init();

    await cubit.enable();

    expect((await db.getSettings()).aiEnabled, isTrue);
    expect(cubit.state.enabled, isTrue);
    expect(cubit.state.status, LocalAiStatus.ready);
  });

  test('a cancelled enable persists nothing', () async {
    installer.error = const InstallCancelled();

    await cubit.enable();

    expect(cubit.state.enabled, isFalse);
    expect((await db.getSettings()).aiEnabled, isFalse);
    expect(runtime.starts, 0);
  });

  for (final failure in InstallFailure.values) {
    test('a $failure enable says so and stays off', () async {
      installer.error = InstallException(failure);

      await cubit.enable();

      expect(cubit.state.installFailure, failure);
      expect(cubit.state.enabled, isFalse);
      expect((await db.getSettings()).aiEnabled, isFalse);
    });
  }

  test('disable stops the server and keeps the files', () async {
    await cubit.enable();

    await cubit.disable();

    expect(runtime.stops, greaterThan(0));
    expect(File(paths.model).existsSync(), isTrue);
    expect(cubit.state.filesOnDisk, isTrue);
    expect((await db.getSettings()).aiEnabled, isFalse);
  });

  test('deleteFiles removes the root and turns AI off', () async {
    await cubit.enable();

    await cubit.deleteFiles();

    expect(Directory(paths.root).existsSync(), isFalse);
    expect(cubit.state.filesOnDisk, isFalse);
    expect((await db.getSettings()).aiEnabled, isFalse);
  });

  test('summarize refuses until ready, then asks the provider', () async {
    expect(() => cubit.summarize('x'), throwsA(isA<AiInvalidResponse>()));

    await cubit.enable();

    expect(await cubit.summarize('x'), 'riassunto 18080');
  });
}
