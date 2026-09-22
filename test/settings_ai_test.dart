import 'package:catui/catui.dart';
import 'package:clockodile/data/db/database.dart';
import 'package:clockodile/features/ai/cubit/ai_cubit.dart';
import 'package:clockodile/features/settings/cubit/theme_cubit.dart';
import 'package:clockodile/features/settings/settings_view.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart' hide ThemeMode;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' show ThemeMode;

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

  Finder aiRow() => find.widgetWithText(CatSettingRow, 'Riassunto delle note');
  Finder aiSwitch() =>
      find.descendant(of: aiRow(), matching: find.byType(Switch));
  bool switchOn(WidgetTester tester) => tester.widget<Switch>(aiSwitch()).value;

  /// The AI section sits below the fold in a test window, so the switch is
  /// scrolled into view before it is tapped.
  Future<void> tapAiSwitch(WidgetTester tester) async {
    await tester.ensureVisible(aiSwitch());
    await tester.pumpAndSettle();
    await tester.tap(aiSwitch());
    await tester.pumpAndSettle();
  }

  testWidgets('the switch is off by default', (tester) async {
    await openSettings(tester);
    expect(switchOn(tester), isFalse);
  });

  testWidgets('turning it on asks first, with the real size', (tester) async {
    await openSettings(tester);
    await tapAiSwitch(tester);

    expect(find.text("Attivare l'AI locale?"), findsOneWidget);
    expect(find.textContaining('1,3 GB'), findsOneWidget);
  });

  testWidgets('Annulla leaves it off and downloads nothing', (tester) async {
    await openSettings(tester);
    await tapAiSwitch(tester);
    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();

    expect(switchOn(tester), isFalse);
    expect(installer.calls, 0);
  });

  testWidgets('Scarica installs and the switch ends on', (tester) async {
    await openSettings(tester);
    await tapAiSwitch(tester);
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
    await tapAiSwitch(tester);

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

  /// The selected segment is the filled one.
  String selectedRetention(WidgetTester tester) => tester
      .widget<Text>(
        find.descendant(
          of: find.descendant(
            of: find.byType(CatSegmented<int>),
            matching: find.byType(FilledButton),
          ),
          matching: find.byType(Text),
        ),
      )
      .data!;

  Future<void> pickRetention(WidgetTester tester, String label) async {
    final segment = find.text(label);
    await tester.ensureVisible(segment);
    await tester.pumpAndSettle();
    await tester.tap(segment);
    await tester.pumpAndSettle();
  }

  testWidgets('the three choices are there, no save button', (tester) async {
    await openSettings(tester);
    expect(find.byType(CatSegmented<int>), findsOneWidget);
    for (final label in ['30 giorni', '45 giorni', '60 giorni']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.widgetWithText(FilledButton, 'Salva'), findsNothing);
    expect(find.byType(TextFormField), findsNothing);
  });

  testWidgets('growing it writes at once and leaves aiEnabled alone', (
    tester,
  ) async {
    await db.saveSettings(
      const SettingsCompanion(aiEnabled: Value(true), retentionDays: Value(45)),
    );
    await openSettings(tester);
    await pickRetention(tester, '60 giorni');

    expect(find.byType(AlertDialog), findsNothing);
    final saved = await db.getSettings();
    expect(saved.retentionDays, 60);
    expect(saved.aiEnabled, isTrue);
  });

  testWidgets('shrinking it asks first, then writes and purges', (
    tester,
  ) async {
    await db.saveSettings(const SettingsCompanion(retentionDays: Value(45)));
    // Inside 45 days, outside 30: only the shrink purges it.
    await db.createEntry(
      'Acme',
      'vecchia',
      startTime: DateTime.now().subtract(const Duration(days: 40)),
    );
    await db.stopOpenSession();
    await openSettings(tester);
    await pickRetention(tester, '30 giorni');

    expect(find.text('Eliminare le attività più vecchie?'), findsOneWidget);
    await tester.tap(find.text('Elimina'));
    await tester.pumpAndSettle();

    expect((await db.getSettings()).retentionDays, 30);
    expect(await db.select(db.entries).get(), isEmpty);
  });

  testWidgets('cancelling a shrink leaves the stored value alone', (
    tester,
  ) async {
    await db.saveSettings(const SettingsCompanion(retentionDays: Value(45)));
    await openSettings(tester);
    await pickRetention(tester, '30 giorni');
    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();

    expect((await db.getSettings()).retentionDays, 45);
    expect(selectedRetention(tester), '45 giorni');
  });

  testWidgets('sections fill the window, the theme picker does not', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await openSettings(tester);

    final page = tester.getSize(find.byType(SettingsView)).width;
    final section = tester.getSize(find.byType(CatSection).first).width;
    expect(section, closeTo(page - AppTokens.pagePadding * 2, 1));
    expect(
      tester.getSize(find.byType(CatSegmented<ThemeMode>)).width,
      lessThan(section),
    );
  });

  testWidgets('no provider, model or WSL controls are left', (tester) async {
    await openSettings(tester);
    expect(find.text('Codex'), findsNothing);
    expect(find.text('Modello'), findsNothing);
    expect(find.text('Modalità WSL'), findsNothing);
  });
}
