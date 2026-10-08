import 'package:clockodile/data/db/database.dart';
import 'package:clockodile/features/clients/clients_view.dart';
import 'package:clockodile/features/clients/cubit/clients_cubit.dart';
import 'package:clockodile/shared/widgets/identicon.dart';
import 'package:drift/native.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'hover.dart';

/// Clienti: create via the header button, rename by tapping the row, delete.
void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    // Hover highlights follow the focus highlight mode, which tests start
    // in touch mode.
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  });
  tearDown(() {
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;
    db.close();
  });

  /// Lets drift's query streams deliver, then settles the frames.
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> pumpView(WidgetTester tester) async {
    await tester.pumpWidget(
      BlocProvider(
        create: (_) => ClientsCubit(db),
        child: const ShadcnApp(home: ClientsView()),
      ),
    );
    await settle(tester);
  }

  Future<void> teardownTree(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await settle(tester);
  }

  Finder nameField() => find.widgetWithText(TextField, 'Nome');

  testWidgets('create, rename, delete', (tester) async {
    await pumpView(tester);
    expect(find.text('Nessun cliente.'), findsOneWidget);

    await tester.tap(find.text('Nuovo cliente'));
    await tester.pumpAndSettle();
    await tester.enterText(nameField(), 'Acme');
    await tester.tap(find.text('Crea'));
    await settle(tester);

    expect(find.text('Acme'), findsOneWidget);
    expect(
      tester.getSize(find.byType(Identicon)),
      const Size.square(Identicon.normal),
    );

    // Pencil is hidden until the row is hovered, and opens the same dialog
    // as tapping the row.
    final mouse = await hoverOver(tester, find.text('Acme'));
    addTearDown(mouse.removePointer);
    await tester.tap(find.byIcon(LucideIcons.pencil));
    await tester.pumpAndSettle();
    await tester.enterText(nameField(), 'Beta');
    await tester.tap(find.text('Salva'));
    await settle(tester);
    expect(find.text('Beta'), findsOneWidget);
    expect((await db.select(db.clients).getSingle()).name, 'Beta');

    await mouse.moveTo(tester.getCenter(find.text('Beta')));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(LucideIcons.trash2));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elimina'));
    await settle(tester);
    expect(await db.select(db.clients).get(), isEmpty);
    expect(find.text('Nessun cliente.'), findsOneWidget);
    await teardownTree(tester);
  });

  testWidgets('search filters the list as you type', (tester) async {
    await db.matchOrCreateClient('Acme');
    await db.matchOrCreateClient('Bianchi');
    await pumpView(tester);
    expect(find.text('Cerca tra i clienti...'), findsOneWidget);
    expect(find.byIcon(LucideIcons.search), findsOneWidget);

    final search = find.widgetWithText(TextField, 'Cerca tra i clienti...');
    await tester.enterText(search, 'AC');
    await tester.pumpAndSettle();
    expect(find.text('Acme'), findsOneWidget);
    expect(find.text('Bianchi'), findsNothing);

    await tester.enterText(search, 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('Nessun cliente trovato.'), findsOneWidget);

    await tester.enterText(search, '');
    await tester.pumpAndSettle();
    expect(find.text('Acme'), findsOneWidget);
    expect(find.text('Bianchi'), findsOneWidget);
  });
}
