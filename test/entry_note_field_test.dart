import 'package:clockodile/data/db/database.dart';
import 'package:clockodile/features/entries/cubit/entries_cubit.dart';
import 'package:clockodile/features/entries/entry_edit_page.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

/// The Nota's AI button, up to the point of pressing it — no test here spawns
/// a process. What pressing it *builds* is covered in ai_command_test.dart.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  /// Opens the create page (edit mode differs only in its sessions list).
  Future<void> openPage(WidgetTester tester, {bool aiEnabled = false}) async {
    await db.saveSettings(SettingsCompanion(aiEnabled: Value(aiEnabled)));
    await tester.pumpWidget(
      RepositoryProvider.value(
        value: db,
        child: BlocProvider(
          create: (_) => EntriesCubit(db),
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => openEntryPage(context),
                  child: const Text('apri'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('apri'));
    await tester.pumpAndSettle();
  }

  Finder noteField() => find.widgetWithText(TextField, 'Nota');
  Finder aiButton() => find.ancestor(
    of: find.byTooltip('Riassumi la nota'),
    matching: find.byType(IconButton),
  );

  const longNote = 'uno due tre quattro cinque sei sette otto nove dieci';

  testWidgets('the Nota grows from three lines to eight, then scrolls', (
    tester,
  ) async {
    await openPage(tester);

    final field = tester.widget<TextField>(noteField());
    expect(field.minLines, 3);
    expect(field.maxLines, 8);
  });

  testWidgets('the button is absent entirely when AI is off', (tester) async {
    await openPage(tester);
    await tester.enterText(noteField(), longNote);
    await tester.pumpAndSettle();

    expect(aiButton(), findsNothing);
  });

  testWidgets('with AI on the button toggles live around ten words', (
    tester,
  ) async {
    await openPage(tester, aiEnabled: true);
    expect(aiButton(), findsOneWidget); // visible, just disabled
    expect(tester.widget<IconButton>(aiButton()).onPressed, isNull);

    await tester.enterText(noteField(), 'uno due tre quattro cinque sei');
    await tester.pumpAndSettle();
    expect(tester.widget<IconButton>(aiButton()).onPressed, isNull);

    await tester.enterText(noteField(), longNote);
    await tester.pumpAndSettle();
    expect(tester.widget<IconButton>(aiButton()).onPressed, isNotNull);

    await tester.enterText(noteField(), 'uno due');
    await tester.pumpAndSettle();
    expect(tester.widget<IconButton>(aiButton()).onPressed, isNull);
  });

  testWidgets('the button is present in edit mode too', (tester) async {
    await db.saveSettings(const SettingsCompanion(aiEnabled: Value(true)));
    await db.createEntry('Acme', longNote, startTime: DateTime.now());
    final entry = await db.select(db.entries).getSingle();
    await tester.pumpWidget(
      RepositoryProvider.value(
        value: db,
        child: BlocProvider(
          create: (_) => EntriesCubit(db),
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => openEntryPage(context, entry: entry),
                  child: const Text('apri'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('apri'));
    await tester.pumpAndSettle();

    expect(aiButton(), findsOneWidget);
    expect(tester.widget<IconButton>(aiButton()).onPressed, isNotNull);

    // Tears the tree down inside the test so the cubit's query stream closes
    // here rather than leaving a pending timer behind.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('the text never runs under the button: padding reserves it', (
    tester,
  ) async {
    await openPage(tester, aiEnabled: true);

    final padding =
        tester.widget<TextField>(noteField()).decoration!.contentPadding
            as EdgeInsets;
    expect(padding.bottom, greaterThan(padding.top));
  });
}
