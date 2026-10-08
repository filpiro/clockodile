import 'package:shadcn_flutter/shadcn_flutter.dart';

import '../utils/format.dart';

/// shadcn's `DatePicker` with the value shown as "22/09/26". `DatePicker`
/// hard-codes US order through a `ShadcnLocalizations` extension, which no
/// translation can override.
class DateField extends StatelessWidget {
  final DateTime? value;
  final ValueChanged<DateTime?>? onChanged;
  final Widget? placeholder;

  const DateField({
    super.key,
    required this.value,
    this.onChanged,
    this.placeholder,
  });

  @override
  Widget build(BuildContext context) => ObjectFormField<DateTime>(
    value: value,
    onChanged: onChanged,
    placeholder: placeholder ?? const Text('Data'),
    trailing: const Icon(LucideIcons.calendarDays),
    mode: PromptMode.dialog,
    builder: (context, value) => Text(dmyShort(value)),
    editorBuilder: (context, handler) => DatePickerDialog(
      initialViewType: CalendarViewType.date,
      selectionMode: CalendarSelectionMode.single,
      initialValue: handler.value == null
          ? null
          : CalendarValue.single(handler.value!),
      onChanged: (value) => handler.value = value == null
          ? null
          : (value as SingleCalendarValue).date,
    ),
  );
}
