import 'package:clockodile/data/db/database.dart';
import 'package:clockodile/features/ai/cubit/ai_cubit.dart';
import 'package:clockodile/features/clients/cubit/clients_cubit.dart';
import 'package:clockodile/features/entries/cubit/entries_cubit.dart';
import 'package:clockodile/features/entries/entries_view.dart';
import 'package:drift/native.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'ai_fakes.dart';
import 'hover.dart';

/// Attività: the header button, the pinned active row and the row actions.
void main() {
  late AppDatabase db;
  late AiCubit ai;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    ai = fakeAiCubit(db);
    // Hover highlights follow the focus highlight mode, which tests start
    // in touch mode.
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  });
  tearDown(() async {
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
    await ai.close();
    await db.close();
  });

  /// Lets drift's query streams deliver, then settles the frames.
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
  }

  Future<void> pumpView(WidgetTester tester) async {
    await tester.pumpWidget(
      RepositoryProvider.value(
        value: db,
        child: MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) => EntriesCubit(db)),
            BlocProvider(create: (_) => ClientsCubit(db)),
            BlocProvider.value(value: ai),
          ],
          child: const ShadcnApp(home: EntriesView()),
        ),
      ),
    );
    await settle(tester);
  }

  /// Drops the tree inside the test, so the cubits' query streams close here
  /// rather than leaving a pending timer behind.
  Future<void> teardownTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  }

  testWidgets('the header button creates an entry born open; Termina ends it', (
    tester,
  ) async {
    await pumpView(tester);
    expect(find.text('Nessuna attività.'), findsOneWidget);

    await tester.tap(find.text('Nuova attività'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.widgetWithText(FormField, 'Cliente'),
        matching: find.byType(TextField),
      ),
      'TestCo',
    );
    await tester.pumpAndSettle();
    expect(find.text('Fine'), findsNothing); // end hidden on create
    await tester.tap(find.text('Salva'));
    await settle(tester);

    expect(find.text('TestCo'), findsOneWidget);
    expect(find.text('in corso'), findsOneWidget);

    // Always visible: no hover needed.
    await tester.tap(find.text('Termina'));
    await settle(tester);

    expect((await db.select(db.sessions).getSingle()).end, isNotNull);
    expect(find.text('in corso'), findsNothing);
    await teardownTree(tester);
  });

  testWidgets('delete confirms before removing the entry', (tester) async {
    await db.createEntry('Acme', '', startTime: DateTime.now());
    await db.stopOpenSession();
    await pumpView(tester);
    expect(find.text('Acme'), findsOneWidget);

    // Delete is hidden until the row is hovered.
    final mouse = await hoverOver(tester, find.text('Acme'));
    addTearDown(mouse.removePointer);

    await tester.tap(find.byIcon(LucideIcons.trash2));
    await tester.pumpAndSettle();
    expect(find.text("Eliminare l'attività?"), findsOneWidget);
    await tester.tap(find.text('Annulla'));
    await settle(tester);
    expect(find.text('Acme'), findsOneWidget);

    await mouse.moveTo(tester.getCenter(find.text('Acme')));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(LucideIcons.trash2));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elimina'));
    await settle(tester);

    expect(await db.select(db.entries).get(), isEmpty);
    expect(find.text('Nessuna attività.'), findsOneWidget);
    await teardownTree(tester);
  });
}
