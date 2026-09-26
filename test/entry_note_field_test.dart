import 'dart:async';

import 'package:clockodile/data/db/database.dart';
import 'package:clockodile/features/ai/cubit/ai_cubit.dart';
import 'package:clockodile/features/clients/cubit/clients_cubit.dart';
import 'package:clockodile/features/entries/cubit/entries_cubit.dart';
import 'package:clockodile/features/entries/entry_edit_page.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
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
            BlocProvider(create: (_) => ClientsCubit(db)),
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

  void setTestWindow(WidgetTester tester, Size size) {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
  }

  const longNote = 'uno due tre quattro cinque sei sette otto nove dieci';

  testWidgets('the Nota grows from three lines to six, then scrolls', (
    tester,
  ) async {
    await openPage(tester);

    final field = tester.widget<TextField>(noteField());
    expect(field.minLines, 3);
    expect(field.maxLines, 6);
  });

  testWidgets(
    'the form places dates beside details, then below on narrow windows',
    (tester) async {
      setTestWindow(tester, const Size(1100, 720));
      await openPage(tester);

      final note = find.widgetWithText(FormField, 'Nota');
      final start = find.byKey(const FormKey(#start)).first;
      expect(tester.getTopLeft(note).dx, lessThan(tester.getTopLeft(start).dx));
      expect(find.byType(VerticalDivider), findsOneWidget);
      expect(find.byType(ListView), findsNWidgets(2));

      tester.view.physicalSize = const Size(1600, 720);
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(note).dx, closeTo(240, 1));

      tester.view.physicalSize = const Size(700, 720);
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(note).dy, lessThan(tester.getTopLeft(start).dy));
      expect(find.byType(VerticalDivider), findsNothing);
      expect(find.byType(ListView), findsOneWidget);
    },
  );

  testWidgets('the session column scrolls independently', (tester) async {
    setTestWindow(tester, const Size(768, 420));
    await db.createEntry('Acme', 'Nota');
    final entry = await db.select(db.entries).getSingle();
    for (var i = 0; i < 6; i++) {
      await db.stopOpenSession();
      await db.activateEntry(entry.id);
    }
    await openPage(tester, entry: entry);

    final lists = find.byType(ListView);
    final left = tester.state<ScrollableState>(
      find.descendant(of: lists.at(0), matching: find.byType(Scrollable)).first,
    );
    final right = tester.state<ScrollableState>(
      find.descendant(of: lists.at(1), matching: find.byType(Scrollable)).first,
    );
    await tester.drag(lists.at(1), const Offset(0, -250));
    await tester.pumpAndSettle();
    expect(right.position.pixels, greaterThan(0));
    expect(left.position.pixels, 0);

    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  for (final width in [1100.0, 700.0]) {
    testWidgets('Ctrl+S saves with the client focused at width $width', (
      tester,
    ) async {
      setTestWindow(tester, Size(width, 720));
      await openPage(tester);
      await tester.enterText(
        find.descendant(
          of: find.widgetWithText(FormField, 'Cliente'),
          matching: find.byType(TextField),
        ),
        'Acme',
      );
      await tester.pump();
      expect(
        tester
            .widget<PrimaryButton>(find.widgetWithText(PrimaryButton, 'Salva'))
            .onPressed,
        isNotNull,
      );
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(await db.select(db.entries).get(), hasLength(1));
    });
  }

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
