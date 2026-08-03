import 'package:drift/native.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:clockodile/data/db/database.dart';
import 'package:clockodile/features/clients/cubit/clients_cubit.dart';
import 'package:clockodile/features/entries/cubit/entries_cubit.dart';
import 'package:clockodile/main.dart';

// Runs on the real Windows runtime (real native sqlite3), driving the real
// UI. In-memory DB so the user's actual database is never touched.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('entry born open via FAB, terminate it, create client',
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
          ],
          child: ClockodileApp(purge: db.purgeExpiredEntries()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Nessuna attività.'), findsOneWidget);

    // --- new entry via FAB: born open, pinned with badge ---
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'Cliente'), 'TestCo');
    await tester.pumpAndSettle();
    expect(find.text('Fine'), findsNothing); // end hidden on create
    await tester.tap(find.text('Salva'));
    await tester.pumpAndSettle();

    expect(find.text('TestCo'), findsOneWidget);
    expect(find.text('In corso'), findsOneWidget);
    final session = (await db.select(db.sessions).get()).single;
    expect(session.end, isNull);

    // --- auto-close: second entry closes the first ---
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextField, 'Cliente'), 'SecondCo');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salva'));
    await tester.pumpAndSettle();

    expect((await db.select(db.entries).get()).length, 2);
    final sessions = await db.select(db.sessions).get();
    expect(sessions.length, 2);
    expect(sessions.where((s) => s.end == null).length, 1);
    expect(find.text('In corso'), findsOneWidget);

    // --- Termina closes the open entry (revealed by mouse hover) ---
    final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await gesture.addPointer(location: Offset.zero);
    addTearDown(gesture.removePointer);
    await gesture.moveTo(tester.getCenter(find.text('SecondCo')));
    await tester.pumpAndSettle();

    final termina = find.text('Termina');
    expect(termina, findsOneWidget);
    await tester.tap(termina);
    await tester.pumpAndSettle();
    expect(
        (await db.select(db.sessions).get()).where((s) => s.end == null),
        isEmpty);
    expect(find.text('In corso'), findsNothing);

    // --- new client via FAB on clients screen ---
    await tester.tap(find.text('Clienti'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Nome'), 'Acme');
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
