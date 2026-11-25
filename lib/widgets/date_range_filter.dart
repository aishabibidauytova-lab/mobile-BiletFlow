import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/models.dart';

/// "From" and "To" date buttons. The range can never be inverted.
class DateRangeFilter extends StatelessWidget {
  final DateTime? from;
  final DateTime? to;
  final void Function(DateTime? from, DateTime? to) onChanged;
  const DateRangeFilter(
      {super.key, required this.from, required this.to, required this.onChanged});

  Widget _button(BuildContext context, bool isFrom) {
    final value = isFrom ? from : to;
    final label = tr(isFrom ? 'filter.from' : 'filter.to');
    return InputChip(
      avatar: const Icon(Icons.calendar_month_outlined, size: 18),
      label: Text(value == null
          ? label
          : '$label: ${formatDateTime(value).substring(0, 10)}'),
      onDeleted: value == null
          ? null
          : () => onChanged(isFrom ? null : from, isFrom ? to : null),
      onPressed: () async {
        final first = isFrom ? DateTime(2020) : (from ?? DateTime(2020));
        final last = isFrom ? (to ?? DateTime(2100)) : DateTime(2100);
        var initial = value ?? DateTime.now();
        if (initial.isBefore(first)) initial = first;
        if (initial.isAfter(last)) initial = last;
        final picked = await showDatePicker(
          context: context,
          initialDate: initial,
          firstDate: first,
          lastDate: last,
        );
        if (picked != null) {
          onChanged(isFrom ? picked : from, isFrom ? to : picked);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 8,
        runSpacing: 4,
        children: [_button(context, true), _button(context, false)],
      );
}
