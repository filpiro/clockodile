import 'package:clockodile/data/db/database.dart';
import 'package:clockodile/features/settings/cubit/theme_cubit.dart';
import 'package:clockodile/features/settings/settings_view.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<void> openSettings(WidgetTester tester) async {
    await tester.pumpWidget(
      RepositoryProvider.value(
        value: db,
        child: BlocProvider(
          create: (_) => ThemeCubit(db),
          child: const MaterialApp(home: Scaffold(body: SettingsView())),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder modelField() => find.widgetWithText(TextField, 'Modello');

  testWidgets('AI is off by default and Claude Code defaults to sonnet/high', (
    tester,
  ) async {
    await openSettings(tester);

    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
    expect(find.text('Sonnet'), findsOneWidget);
    expect(find.text('High'), findsOneWidget);
  });

  testWidgets('switching provider away and back keeps the typed values', (
    tester,
  ) async {
    await openSettings(tester);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Codex'));
    await tester.pumpAndSettle();
    await tester.enterText(modelField(), 'gpt-5');
    await tester.tap(find.text('OpenCode'));
    await tester.pumpAndSettle();
    expect(find.text('gpt-5'), findsNothing); // OpenCode has its own pair
    await tester.tap(find.text('Codex'));
    await tester.pumpAndSettle();

    expect(find.text('gpt-5'), findsOneWidget);
  });

  testWidgets('Salva persists the AI settings', (tester) async {
    await openSettings(tester);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Codex'));
    await tester.pumpAndSettle();
    await tester.enterText(modelField(), 'gpt-5');

    await tester.tap(find.widgetWithText(FilledButton, 'Salva'));
    await tester.pumpAndSettle();

    final saved = await db.getSettings();
    expect(saved.aiEnabled, isTrue);
    expect(saved.aiProvider, AiProvider.codex.name);
    expect(saved.aiCodexModel, 'gpt-5');
  });

  testWidgets('a shell metacharacter is refused, naming the field', (
    tester,
  ) async {
    await openSettings(tester);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Codex'));
    await tester.pumpAndSettle();
    await tester.enterText(modelField(), 'gpt-5; rm -rf /');

    await tester.tap(find.widgetWithText(FilledButton, 'Salva'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Modello Codex'), findsOneWidget);
    expect((await db.getSettings()).aiCodexModel, ''); // nothing written
  });

  testWidgets('turning AI back off makes a bad value stop blocking Salva', (
    tester,
  ) async {
    await openSettings(tester);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Codex'));
    await tester.pumpAndSettle();
    await tester.enterText(modelField(), 'gpt-5; rm -rf /');
    await tester.tap(find.byType(Switch)); // back off: section is inert
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Salva'));
    await tester.pumpAndSettle();

    expect(find.text('Impostazioni salvate'), findsOneWidget);
  });
}
