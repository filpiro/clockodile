import 'package:clockodile/shadcn_it.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart';

void main() {
  testWidgets('shadcn strings are Italian, missed ones fall back to English',
      (tester) async {
    late ShadcnLocalizations l;
    await tester.pumpWidget(ShadcnApp(
      locale: const Locale('it'),
      supportedLocales: const [Locale('it')],
      localizationsDelegates: const [ShadcnLocalizationsIt.delegate],
      home: Builder(builder: (context) {
        l = ShadcnLocalizations.of(context);
        return const SizedBox();
      }),
    ));
    expect(l.buttonCancel, 'Annulla');
    expect(l.menuCopy, 'Copia');
    expect(l.colorRed, 'Red');
  });
}
