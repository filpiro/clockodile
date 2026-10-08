import 'package:shadcn_flutter/shadcn_flutter.dart';

import 'date_field.dart';

/// Midnight of [t]'s day.
DateTime dateOnly(DateTime t) => DateTime(t.year, t.month, t.day);

DateTime today() => dateOnly(DateTime.now());

DateTime yesterday() => today().subtract(const Duration(days: 1));

/// Oggi / Ieri toggles beside a [DateField], shared by Attività and Report.
/// There is always exactly one [day]; the toggles are shortcuts that light up
/// when [day] is today or yesterday.
class DateFilterBar extends StatelessWidget {
  final DateTime day;
  final ValueChanged<DateTime> onDay;

  const DateFilterBar({super.key, required this.day, required this.onDay});

  @override
  Widget build(BuildContext context) {
    Widget toggle(DateTime target, String label) => Toggle(
      value: day == target,
      onChanged: (_) => onDay(target),
      style: const ButtonStyle.outline(),
      child: Text(label),
    );
    return Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        toggle(today(), 'Oggi'),
        toggle(yesterday(), 'Ieri'),
        DateField(
          // A toggle and the custom date never show at once.
          value: day == today() || day == yesterday() ? null : day,
          onChanged: (d) {
            if (d != null) onDay(d);
          },
        ),
      ],
    );
  }
}
