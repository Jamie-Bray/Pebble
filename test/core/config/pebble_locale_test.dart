import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart' show TimeOfDay;
import 'package:pebble_routines/core/config/pebble_locale.dart';
import 'package:pebble_routines/core/ui/pebble_time.dart';

void main() {
  tearDown(() => Intl.defaultLocale = null);

  test('uses the first supported English region on the device', () {
    expect(
      resolvePebbleLocale(const [Locale('fr', 'FR'), Locale('en', 'AU')]),
      const Locale('en', 'AU'),
    );
    expect(
      resolvePebbleLocale(const [Locale('en', 'US')]),
      const Locale('en', 'US'),
    );
  });

  test('falls back to UK English for other languages and regions', () {
    expect(
      resolvePebbleLocale(const [Locale('de', 'DE')]),
      const Locale('en', 'GB'),
    );
    expect(
      resolvePebbleLocale(const [Locale('en', 'PH')]),
      const Locale('en', 'GB'),
    );
    expect(resolvePebbleLocale(null), const Locale('en', 'GB'));
  });

  test('UK dates read day-month and times are 24-hour', () async {
    await configurePebbleDateLocale(const Locale('en', 'GB'));
    final at = DateTime(2026, 10, 3, 8, 4);
    expect(DateFormat.MMMEd().format(at), 'Sat 3 Oct');
    expect(DateFormat.jm().format(at), '08:04');
  });

  test('US dates read month-day with AM/PM', () async {
    await configurePebbleDateLocale(const Locale('en', 'US'));
    final at = DateTime(2026, 10, 3, 8, 4);
    expect(DateFormat.MMMEd().format(at), 'Sat, Oct 3');
    expect(DateFormat.jm().format(at), matches(RegExp(r'^8:04\sAM$')));
  });

  test('stored reminder times survive a UK English locale', () async {
    await configurePebbleDateLocale(const Locale('en', 'GB'));
    // Existing rows were written as "8:15 PM"; they must still load.
    expect(
      parseStoredClockTime('8:15 PM'),
      const TimeOfDay(hour: 20, minute: 15),
    );
    expect(
      parseStoredClockTime('12:05 AM'),
      const TimeOfDay(hour: 0, minute: 5),
    );
    final encoded = encodeStoredClockTime(const TimeOfDay(hour: 7, minute: 30));
    expect(encoded, '7:30 AM');
    expect(parseStoredClockTime(encoded), const TimeOfDay(hour: 7, minute: 30));
    expect(parseStoredClockTime('not a time'), isNull);
  });
}
