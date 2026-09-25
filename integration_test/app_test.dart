import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;
import 'package:clockodile/data/db/database.dart';
import 'package:clockodile/features/clients/cubit/clients_cubit.dart';
import 'package:clockodile/features/entries/cubit/entries_cubit.dart';
import 'package:clockodile/features/report/cubit/report_cubit.dart';
import 'package:clockodile/features/settings/cubit/theme_cubit.dart';
import 'package:clockodile/main.dart';

import '../test/ai_fakes.dart';

// Runs on the real Windows runtime (real native sqlite3), driving the real
// UI. In-memory DB so the user's actual database is never touched.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Finder clientField() => find.descendant(
      of: find.widgetWithText(shadcn.FormField, 'Cliente'),
      matching: find.byType(shadcn.TextField));

  testWidgets('entry born open via header button, terminate it, create client',
      (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      RepositoryProvider.value(
        value: db,
        child: MultiBlocProvider(
          providers: [
            BlocProvider(create: (_) => EntriesCubit(db)),
            BlocProvider(create: (_) => ClientsCubit(db)),
            BlocProvider(create: (_) => ReportCubit(db)),
            BlocProvider(create: (_) => ThemeCubit(db)),
            BlocProvider(create: (_) => fakeAiCubit(db)),
          ],
          child: const ClockodileApp(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Nessuna attività.'), findsOneWidget);

    // --- new entry via the header button: born open, pinned with badge ---
    await tester.tap(find.text('Nuova attività'));
    await tester.pumpAndSettle();
    await tester.enterText(clientField(), 'TestCo');
    await tester.pumpAndSettle();
    expect(find.text('Fine'), findsNothing); // end hidden on create
    await tester.tap(find.text('Salva'));
    await tester.pumpAndSettle();

    expect(find.text('TestCo'), findsOneWidget);
    expect(find.text('in corso'), findsOneWidget);
    final session = (await db.select(db.sessions).get()).single;
    expect(session.end, isNull);

    // --- auto-close: second entry closes the first ---
    await tester.tap(find.text('Nuova attività'));
    await tester.pumpAndSettle();
    await tester.enterText(clientField(), 'SecondCo');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salva'));
    await tester.pumpAndSettle();

    expect((await db.select(db.entries).get()).length, 2);
    final sessions = await db.select(db.sessions).get();
    expect(sessions.length, 2);
    expect(sessions.where((s) => s.end == null).length, 1);
    expect(find.text('in corso'), findsOneWidget);

    // --- Termina closes the open entry (always visible) ---
    final termina = find.text('Termina');
    expect(termina, findsOneWidget);
    await tester.tap(termina);
    await tester.pumpAndSettle();
    expect(
        (await db.select(db.sessions).get()).where((s) => s.end == null),
        isEmpty);
    expect(find.text('in corso'), findsNothing);

    // --- new client via header button on clients screen ---
    await tester.tap(find.text('Clienti'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Nuovo cliente'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(shadcn.TextField, 'Nome'), 'Acme');
    await tester.tap(find.text('Crea'));
    await tester.pumpAndSettle();

    expect(find.text('Acme'), findsOneWidget);
    expect((await db.select(db.clients).get()).length, 3);

    // --- Ctrl+N from Clienti: switches to Attività and opens the dialog ---
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyN);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyN);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(find.text('Nuova attività'), findsOneWidget);
    await tester.tap(find.text('Annulla'));
    await tester.pumpAndSettle();
  });
}
