import 'package:flutter/material.dart';

import '../../shared/utils/snack_bar_helper.dart';

/// Picks a future date + time for scheduling a donation appointment.
Future<DateTime?> pickDonorAppointmentDateTime(BuildContext context) async {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final date = await showDatePicker(
    context: context,
    initialDate: today.add(const Duration(days: 1)),
    firstDate: today,
    lastDate: now.add(const Duration(days: 30)),
  );
  if (date == null || !context.mounted) return null;

  final isToday =
      date.year == today.year &&
      date.month == today.month &&
      date.day == today.day;
  final initialTime = isToday
      ? TimeOfDay.fromDateTime(now.add(const Duration(minutes: 15)))
      : const TimeOfDay(hour: 9, minute: 0);

  final time = await showTimePicker(context: context, initialTime: initialTime);
  if (time == null || !context.mounted) return null;

  final combined = DateTime(
    date.year,
    date.month,
    date.day,
    time.hour,
    time.minute,
  );
  if (!combined.isAfter(now)) {
    SnackBarHelper.notice(context, 'Choose a date and time in the future.');
    return null;
  }
  return combined;
}
