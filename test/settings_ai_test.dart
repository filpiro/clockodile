import 'package:clockodile/data/db/database.dart';
import 'package:clockodile/features/ai/cubit/ai_cubit.dart';
import 'package:clockodile/features/settings/cubit/theme_cubit.dart';
import 'package:clockodile/features/settings/settings_view.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ai_fakes.dart';

/// Settings → AI on Windows, the only platform that renders it.
void main() {
  late AppDatabase db;
  late AiCubit ai;
  late FakeInstaller installer;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    ai = fakeAiCubit(db);
    installer = ai.installer as FakeInstaller;
  });
  tearDown(() async {
    await ai.close();
    await db.close();
  });

  Future<void> openSettings(WidgetTester tester) async {
    await tester.runAsync(ai.init);
    await tester.pumpWidget(
      RepositoryProvider.value(
        value: db,
        child: MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) => ThemeCubit(db)),
            BlocProvider.value(value: ai),
          ],
          child: const MaterialApp(home: Scaffold(body: SettingsView())),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder aiSwitch() =>
      find.widgetWithText(SwitchListTile, 'Riassunto delle note');
  bool switchOn(WidgetTester tester) =>
      tester.widget<SwitchListTile>(aiSwitch()).value;

  testWidgets('the switch is off by default', (tester) async {
    await openSettings(tester);
    expect(switchOn(tester), isFalse);
  });

  testWidgets('turning it on asks first, with the real size', (tester) async {
    await openSettings(tester);
    await tester.tap(aiSwitch());
    await tester.pumpAndSettle();

    expect(find.text("Attivare l'AI locale?"), findsOneWidget);
    expect(find.textContaining('1,3 GB'), findsOneWidget);
  });

  testWidgets('Annulla leaves it off and downloads nothing', (tester) async {
    await openSettings(tester);
    await tester.tap(aiSwitch());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();

    expect(switchOn(tester), isFalse);
    expect(installer.calls, 0);
  });

  testWidgets('Scarica installs and the switch ends on', (tester) async {
    await openSettings(tester);
    await tester.tap(aiSwitch());
    await tester.pumpAndSettle();
    await tester.tap(find.text('Scarica'));
    await tester.pumpAndSettle();

    expect(installer.calls, 1);
    expect(find.text('Download AI locale'), findsNothing);
    expect(switchOn(tester), isTrue);
  });

  testWidgets('with the files already there it turns on without asking', (
    tester,
  ) async {
    writeInstalledFiles(ai.paths);
    await openSettings(tester);
    await tester.tap(aiSwitch());
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(installer.calls, 0);
    expect(switchOn(tester), isTrue);
  });

  testWidgets('Elimina modello is hidden without files', (tester) async {
    await openSettings(tester);
    expect(find.textContaining('Elimina modello'), findsNothing);
  });

  testWidgets('Elimina modello shows with files on disk', (tester) async {
    writeInstalledFiles(ai.paths);
    await openSettings(tester);
    expect(find.text('Elimina modello (1,3 GB)'), findsOneWidget);
  });

  testWidgets('Salva writes retention and leaves aiEnabled alone', (
    tester,
  ) async {
    await db.saveSettings(const SettingsCompanion(aiEnabled: Value(true)));
    await openSettings(tester);
    await tester.enterText(find.byType(TextFormField), '99');
    final salva = find.widgetWithText(FilledButton, 'Salva');
    await tester.ensureVisible(salva);
    await tester.tap(salva);
    await tester.pumpAndSettle();

    final saved = await db.getSettings();
    expect(saved.retentionDays, 99);
    expect(saved.aiEnabled, isTrue);
  });

  testWidgets('no provider, model or WSL controls are left', (tester) async {
    await openSettings(tester);
    expect(find.text('Codex'), findsNothing);
    expect(find.text('Modello'), findsNothing);
    expect(find.text('Modalità WSL'), findsNothing);
  });
}
