import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// The time of a check as the device shows times: "8:02 AM", or "08:02" with
/// the 24-hour setting on (DESIGN_DIRECTION.md §3.1 "AM/PM").
String formatCheckTime(BuildContext context, DateTime at) {
  final localizations = MaterialLocalizations.of(context);
  return localizations.formatTimeOfDay(
    TimeOfDay.fromDateTime(at.toLocal()),
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );
}

/// Splits "8:02 AM" into ("8:02", "AM"); a 24-hour time has no meridiem.
(String, String?) splitMeridiem(String formatted) {
  final trimmed = formatted.trim();
  // The meridiem is the trailing run without digits ("AM", "p.m.").
  final match = RegExp(r'^(.*\d)[\s  ]*(\D+)$').firstMatch(trimmed);
  if (match == null) return (trimmed, null);
  final meridiem = match.group(2)!.trim();
  if (meridiem.isEmpty) return (trimmed, null);
  return (match.group(1)!.trim(), meridiem);
}

/// A big serif time ("08:04", or "8:04" with a small "AM") for the
/// completion screen and the Home "Checked" card. The meridiem is set at 45%
/// of the size, on the same baseline.
class PebbleBigTime extends StatelessWidget {
  const PebbleBigTime({
    super.key,
    required this.at,
    required this.style,
    this.textAlign = TextAlign.start,
  });

  final DateTime at;
  final TextStyle style;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final formatted = formatCheckTime(context, at);
    final (time, meridiem) = splitMeridiem(formatted);
    final size = style.fontSize ?? 56;
    return Semantics(
      label: formatted,
      excludeSemantics: true,
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: time),
            if (meridiem != null)
              TextSpan(
                text: ' $meridiem',
                style: style.copyWith(fontSize: size * 0.45, letterSpacing: 0),
              ),
          ],
        ),
        maxLines: 1,
        softWrap: false,
        textAlign: textAlign,
        style: style.copyWith(
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

/// Reminder times are stored as text ("8:15 PM"). The storage format is fixed
/// to US English so it never changes with the reader's region: UK English
/// writes "8:15 pm" and cannot read "8:15 PM" back.
final DateFormat _storedClockFormat = DateFormat('h:mm a', 'en_US');

String encodeStoredClockTime(TimeOfDay time) {
  final now = DateTime.now();
  return _storedClockFormat.format(
    DateTime(now.year, now.month, now.day, time.hour, time.minute),
  );
}

TimeOfDay? parseStoredClockTime(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  try {
    final parsed = _storedClockFormat.parse(value.trim());
    return TimeOfDay(hour: parsed.hour, minute: parsed.minute);
  } catch (_) {
    return null;
  }
}

/// A stored reminder time as the device shows times; unreadable values are
/// shown unchanged.
String formatStoredClockTime(BuildContext context, String stored) {
  final time = parseStoredClockTime(stored);
  if (time == null) return stored;
  return MaterialLocalizations.of(context).formatTimeOfDay(
    time,
    alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
  );
}
