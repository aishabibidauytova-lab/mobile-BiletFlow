import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/models.dart';

/// Read-only form field that opens a date picker followed by a time picker.
class DateTimeField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final bool clearable;
  final String? errorText;

  const DateTimeField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.clearable = true,
    this.errorText,
  });

  Future<void> _pick(BuildContext context) async {
    final now = DateTime.now();
    final initial = value ?? now.add(const Duration(days: 1));
    final first = initial.isBefore(now) ? initial : now;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(first.year, first.month, first.day),
      lastDate: DateTime(now.year + 5),
    );
    if (date == null || !context.mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(value ?? DateTime(2000, 1, 1, 18)),
    );
    if (time == null) return;
    onChanged(DateTime(date.year, date.month, date.day, time.hour, time.minute));
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => _pick(context),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          errorText: errorText,
          suffixIcon: value != null && clearable
              ? IconButton(
                  tooltip: tr('form.clear'),
                  icon: const Icon(Icons.close),
                  onPressed: () => onChanged(null),
                )
              : const Icon(Icons.calendar_month_outlined),
        ),
        child: Text(
          value == null ? '—' : formatDateTime(value!),
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}
