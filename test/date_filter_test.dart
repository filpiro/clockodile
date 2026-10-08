import 'package:clockodile/data/db/database.dart';
import 'package:clockodile/features/entries/cubit/entries_cubit.dart';
import 'package:clockodile/shared/widgets/date_field.dart';
import 'package:clockodile/shared/widgets/date_filter_bar.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

Widget _host(Widget child) => ShadcnApp(home: Scaffold(child: child));

void main() {
  group('EntriesCubit day filter', () {
    late AppDatabase db;
    late EntriesCubit cubit;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      cubit = EntriesCubit(db);
    });
    tearDown(() async {
      await cubit.close();
      await db.close();
    });

    test('starts on today', () => expect(cubit.state.day, today()));

    test('setDay keeps only the date and shows only that day', () async {
      final day = DateTime(2026, 3, 10);
      await db.createEntry(
        'Acme',
        'in',
        startTime: day.add(const Duration(hours: 9)),
      );
      await db.stopOpenSession();
      await db.createEntry('Acme', 'out', startTime: DateTime(2026, 3, 11, 9));
      await db.stopOpenSession();

      cubit.setDay(day.add(const Duration(hours: 15)));
      expect(cubit.state.day, day);
      await expectLater(
        cubit.stream.map((s) => s.rows.map((r) => r.entry.note).toList()),
        emitsThrough(['in']),
      );
    });
  });

  group('DateFilterBar', () {
    testWidgets('Oggi lit on today; Ieri reports yesterday', (tester) async {
      DateTime? picked;
      await tester.pumpWidget(
        _host(DateFilterBar(day: today(), onDay: (d) => picked = d)),
      );
      Toggle t(String label) =>
          tester.widget(find.widgetWithText(Toggle, label));
      expect(t('Oggi').value, isTrue);
      expect(t('Ieri').value, isFalse);
      expect(find.text('Data'), findsOneWidget); // custom date cleared

      await tester.tap(find.text('Ieri'));
      expect(picked, yesterday());
    });

    testWidgets('custom day lights no toggle', (tester) async {
      await tester.pumpWidget(
        _host(DateFilterBar(day: DateTime(2026, 3, 10), onDay: (_) {})),
      );
      for (final label in ['Oggi', 'Ieri']) {
        expect(
          tester.widget<Toggle>(find.widgetWithText(Toggle, label)).value,
          isFalse,
        );
      }
      expect(find.text('10/03/26'), findsOneWidget);
    });
  });

  testWidgets('DateField shows dd/mm/yy', (tester) async {
    await tester.pumpWidget(_host(DateField(value: DateTime(2026, 9, 22))));
    expect(find.text('22/09/26'), findsOneWidget);
  });
}
