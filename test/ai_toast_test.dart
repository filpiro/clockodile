import 'dart:async';

import 'package:clockodile/data/db/database.dart';
import 'package:clockodile/features/ai/ai_toast.dart';
import 'package:clockodile/features/ai/cubit/ai_cubit.dart';
import 'package:clockodile/features/ai/llama_runtime.dart';
import 'package:clockodile/shared/widgets/app_toast.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' hide showToast;

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
    // The toast slot is module-global: leave none of it to the next test.
    dismissToast();
    await ai.close();
    await db.close();
  });

  /// testWidgets, then the AI toast's year-long timer run out: shadcn never
  /// cancels it, and the pending-timer check comes before any tearDown.
  void toastTest(String description, WidgetTesterCallback body) =>
      testWidgets(description, (tester) async {
        await body(tester);
        await tester.pump(const Duration(days: 366));
      });

  /// The app's arrangement: the listener above the Navigator, the toast layer
  /// ShadcnApp's own.
  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(
      BlocProvider.value(
        value: ai,
        child: ShadcnApp(
          navigatorKey: navigatorKey,
          builder: (context, child) =>
              AiToastHost(navigatorKey: navigatorKey, child: child!),
          home: const SizedBox(),
        ),
      ),
    );
    // Not pumpAndSettle: the starting state's spinner never settles.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

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
    await pumpApp(tester);
  }

  toastTest('no toast when AI is off', (tester) async {
    await pumpApp(tester);
    expect(find.byType(IconButton), findsNothing);
  });

  toastTest('no toast when ready', (tester) async {
    await openWith(tester);
    expect(ai.state.status, LocalAiStatus.ready);
    expect(find.byType(IconButton), findsNothing);
  });

  toastTest('missing files offer Aggiorna with the size', (tester) async {
    await openWith(tester, installed: false);
    expect(find.text('File AI mancanti o da aggiornare'), findsOneWidget);
    expect(find.text('Aggiorna (1,3 GB)'), findsOneWidget);
  });

  toastTest('starting shows a spinner and no action', (tester) async {
    runtime.outcomes.add(Completer<int>().future);
    await openWith(tester);
    expect(find.text('Avvio AI locale…'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byType(OutlineButton), findsNothing);
  });

  toastTest('a failed start offers Riprova', (tester) async {
    runtime.outcomes.add(const StartFailed('boom'));
    await openWith(tester);
    expect(find.text('AI locale non avviata'), findsOneWidget);
    expect(find.text('Riprova'), findsOneWidget);
  });

  toastTest('no free port names the range', (tester) async {
    runtime.outcomes.add(const NoFreePort());
    await openWith(tester);
    expect(
      find.text('AI locale non avviata: nessuna porta libera (18080–18099)'),
      findsOneWidget,
    );
    expect(find.text('Riprova'), findsOneWidget);
  });

  toastTest('the toast is sticky and the close X takes it away', (
    tester,
  ) async {
    runtime.outcomes.add(const StartFailed('boom'));
    await openWith(tester);
    // No timer: it is still there long after a message toast would have gone.
    await tester.pump(const Duration(seconds: 30));
    expect(find.text('AI locale non avviata'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Chiudi'));
    await tester.pumpAndSettle();
    expect(find.text('AI locale non avviata'), findsNothing);
  });

  toastTest('a resolved state clears the toast', (tester) async {
    runtime.outcomes.add(const StartFailed('boom'));
    await openWith(tester);
    expect(find.text('AI locale non avviata'), findsOneWidget);
    runtime.outcomes.add(Future.value(18080));
    await tester.runAsync(() async {
      unawaited(ai.retry());
      await ai.stream.firstWhere((s) => s.status == LocalAiStatus.ready);
    });
    await tester.pumpAndSettle();
    expect(find.text('AI locale non avviata'), findsNothing);
  });

  toastTest('a message stacks over the AI toast and hands it back', (
    tester,
  ) async {
    runtime.outcomes.add(const StartFailed('boom'));
    await openWith(tester);
    showToast('Nota copiata');
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Nota copiata'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('Nota copiata'), findsNothing);
    expect(find.text('AI locale non avviata'), findsOneWidget);
  });

  toastTest('closing the sticky toast keeps it closed', (tester) async {
    runtime.outcomes.add(const StartFailed('boom'));
    await openWith(tester);
    await tester.tap(find.bySemanticsLabel('Chiudi'));
    await tester.pumpAndSettle();
    showToast('Nota copiata');
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(find.text('AI locale non avviata'), findsNothing);
  });

  toastTest('messages stack, and go after 5s', (tester) async {
    await pumpApp(tester);
    showToast('Nota copiata');
    await tester.pumpAndSettle();
    showToast('Esportazione fallita');
    await tester.pumpAndSettle();
    expect(find.text('Nota copiata'), findsOneWidget);
    expect(find.text('Esportazione fallita'), findsOneWidget);
    // They have a timer, unlike the Local Model's.
    await tester.pump(const Duration(seconds: 4));
    expect(find.text('Esportazione fallita'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(find.text('Nota copiata'), findsNothing);
    expect(find.text('Esportazione fallita'), findsNothing);
  });

  toastTest('a new AI state replaces the AI toast, not the stack', (
    tester,
  ) async {
    runtime.outcomes.add(const StartFailed('boom'));
    await openWith(tester);
    showToast('Nota copiata');
    runtime.outcomes.add(Completer<int>().future);
    // Starting is emitted before retry's first await.
    unawaited(ai.retry());
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('AI locale non avviata'), findsNothing);
    expect(find.text('Avvio AI locale…'), findsOneWidget);
    expect(find.text('Nota copiata'), findsOneWidget);
  });
}
