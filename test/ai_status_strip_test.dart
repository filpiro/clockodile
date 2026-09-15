import 'dart:async';

import 'package:clockodile/data/db/database.dart';
import 'package:clockodile/features/ai/ai_status_strip.dart';
import 'package:clockodile/features/ai/cubit/ai_cubit.dart';
import 'package:clockodile/features/ai/llama_runtime.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ai_fakes.dart';

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

  Future<void> pumpStrip(WidgetTester tester) async {
    await tester.pumpWidget(
      BlocProvider.value(
        value: ai,
        child: MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const Expanded(child: SizedBox()),
                AiStatusStrip(navigatorKey: GlobalKey()),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  double height(WidgetTester tester) =>
      tester.getSize(find.byType(AiStatusStrip)).height;

  /// AI on in the DB, then the app-open path.
  Future<void> openWith(WidgetTester tester, {bool installed = true}) async {
    await tester.runAsync(() async {
      await db.saveSettings(const SettingsCompanion(aiEnabled: Value(true)));
      if (installed) writeInstalledFiles(ai.paths);
      unawaited(ai.init());
      await ai.stream.firstWhere(
        (s) => s.status != LocalAiStatus.notInstalled || !installed,
      );
    });
    await pumpStrip(tester);
  }

  testWidgets('takes no space when AI is off', (tester) async {
    await pumpStrip(tester);
    expect(height(tester), 0);
  });

  testWidgets('takes no space when ready', (tester) async {
    await openWith(tester);
    expect(ai.state.status, LocalAiStatus.ready);
    expect(height(tester), 0);
  });

  testWidgets('missing files offer Aggiorna with the size', (tester) async {
    await openWith(tester, installed: false);
    expect(find.text('File AI mancanti o da aggiornare'), findsOneWidget);
    expect(find.text('Aggiorna (1,3 GB)'), findsOneWidget);
    // A strip, not a bar: the action button must not inflate it to 48.
    expect(height(tester), lessThan(48));
  });

  testWidgets('starting shows a spinner and no action', (tester) async {
    runtime.outcomes.add(Completer<int>().future);
    await openWith(tester);
    expect(find.text('Avvio AI locale…'), findsOneWidget);
    expect(find.byType(TextButton), findsNothing);
  });

  testWidgets('a failed start offers Riprova', (tester) async {
    runtime.outcomes.add(const StartFailed('boom'));
    await openWith(tester);
    expect(find.text('AI locale non avviata'), findsOneWidget);
    expect(find.text('Riprova'), findsOneWidget);
  });

  testWidgets('no free port names the range', (tester) async {
    runtime.outcomes.add(const NoFreePort());
    await openWith(tester);
    expect(
      find.text('AI locale non avviata: nessuna porta libera (18080–18099)'),
      findsOneWidget,
    );
    expect(find.text('Riprova'), findsOneWidget);
  });
}
