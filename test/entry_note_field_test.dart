import 'dart:async';

import 'package:clockodile/data/db/database.dart';
import 'package:clockodile/features/ai/cubit/ai_cubit.dart';
import 'package:clockodile/features/entries/cubit/entries_cubit.dart';
import 'package:clockodile/features/entries/entry_edit_page.dart';
import 'package:drift/native.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'ai_fakes.dart';

/// The Nota's AI button, up to the point of pressing it — no test here spawns
/// a process or opens a socket; the Local Model is faked.
void main() {
  late AppDatabase db;
  late AiCubit ai;
  late FakeRuntime runtime;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    runtime = FakeRuntime();
    ai = fakeAiCubit(db, runtime: runtime);
  });
  tearDown(() async {
    await ai.close();
    await db.close();
  });

  /// Turns AI on and waits until the Local Model reaches [status].
  Future<void> aiTo(WidgetTester tester, LocalAiStatus status) =>
      tester.runAsync(() async {
        unawaited(ai.enable());
        await ai.stream.firstWhere((s) => s.status == status);
      });

  /// Opens the create page, or the edit page for [entry].
  Future<void> openPage(WidgetTester tester, {Entry? entry}) async {
    await tester.pumpWidget(
      RepositoryProvider.value(
        value: db,
        child: MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) => EntriesCubit(db)),
            BlocProvider.value(value: ai),
          ],
          child: ShadcnApp(
            home: Builder(
              builder: (context) => Scaffold(
                child: TextButton(
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
  }

  Finder noteField() => find.descendant(
    of: find.widgetWithText(FormField, 'Nota'),
    matching: find.byType(TextField),
  );
  Finder aiButton() => find.ancestor(
    of: find.byIcon(LucideIcons.sparkles),
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

  testWidgets('while the model starts the button shows but stays disabled', (
    tester,
  ) async {
    runtime.outcomes.add(Completer<int>().future);
    await aiTo(tester, LocalAiStatus.starting);
    await openPage(tester);
    await tester.enterText(noteField(), longNote);
    await tester.pumpAndSettle();

    expect(aiButton(), findsOneWidget);
    expect(tester.widget<IconButton>(aiButton()).onPressed, isNull);
  });

  testWidgets('when ready the button toggles live around ten words', (
    tester,
  ) async {
    await aiTo(tester, LocalAiStatus.ready);
    await openPage(tester);
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
    await aiTo(tester, LocalAiStatus.ready);
    await db.createEntry('Acme', longNote, startTime: DateTime.now());
    final entry = await db.select(db.entries).getSingle();
    await openPage(tester, entry: entry);

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
    await aiTo(tester, LocalAiStatus.ready);
    await openPage(tester);

    final padding = tester.widget<TextField>(noteField()).padding as EdgeInsets;
    expect(padding.bottom, greaterThan(padding.top));
  });
}
