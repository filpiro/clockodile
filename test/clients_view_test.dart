import 'package:clockodile/data/db/database.dart';
import 'package:clockodile/features/clients/clients_view.dart';
import 'package:clockodile/features/clients/cubit/clients_cubit.dart';
import 'package:clockodile/shared/widgets/identicon.dart';
import 'package:drift/native.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

/// Clienti: create via the header button, rename by tapping the row, delete.
void main() {
  late AppDatabase db;

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  /// Lets drift's query streams deliver, then settles the frames.
  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
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

    await tester.tap(find.text('Acme'));
    await tester.pumpAndSettle();
    await tester.enterText(nameField(), 'Beta');
    await tester.tap(find.text('Salva'));
    await settle(tester);
    expect(find.text('Beta'), findsOneWidget);
    expect((await db.select(db.clients).getSingle()).name, 'Beta');

    await tester.tap(find.byIcon(LucideIcons.trash2));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Elimina'));
    await settle(tester);
    expect(await db.select(db.clients).get(), isEmpty);
    expect(find.text('Nessun cliente.'), findsOneWidget);
    await teardownTree(tester);
  });
}
