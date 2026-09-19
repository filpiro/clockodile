import 'package:catui/catui.dart';
import 'package:flutter/material.dart';

import '../utils/format.dart';

enum DateFilter { today, yesterday, day, all }

/// The one date picker: every screen picking a day goes through here so the
/// allowed range stays in one place.
Future<DateTime?> pickDay(BuildContext context, DateTime? initial) =>
    showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

/// Oggi / Ieri / Data chips (plus Tutte when [showAll]) shared by Attività and
/// Report. Picking "Data" opens [pickDay] and reports the day via [onPickDay].
class DateFilterBar extends StatelessWidget {
  final DateFilter filter;
  final DateTime? pickedDay;
  final bool showAll;
  final ValueChanged<DateFilter> onFilter;
  final ValueChanged<DateTime> onPickDay;

  const DateFilterBar({
    super.key,
    required this.filter,
    required this.pickedDay,
    required this.onFilter,
    required this.onPickDay,
    this.showAll = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget chip(DateFilter f, String label) => ChoiceChip(
      label: Text(label),
      showCheckmark: false,
      selected: filter == f,
      onSelected: (_) => onFilter(f),
    );
    return Wrap(
      spacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        chip(DateFilter.today, 'Oggi'),
        chip(DateFilter.yesterday, 'Ieri'),
        ChoiceChip(
          avatar: const Icon(LucideIcons.calendar, size: 16),
          showCheckmark: false,
          label: Text(pickedDay == null ? 'Data' : dmyShort(pickedDay!)),
          selected: filter == DateFilter.day,
          onSelected: (_) async {
            final day = await pickDay(context, pickedDay);
            if (day != null) onPickDay(day);
          },
        ),
        if (showAll) chip(DateFilter.all, 'Tutte'),
      ],
    );
  }
}
