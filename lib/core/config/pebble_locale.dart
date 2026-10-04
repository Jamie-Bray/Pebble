import 'package:flutter/widgets.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

/// Pebble's copy is English only, but dates and times follow the reader's
/// region: "Sat 3 Oct, 08:04" in the UK, "Sat, Oct 3, 8:04 AM" in the US.
/// Devices set to another language get UK English formats.
const pebbleSupportedLocales = <Locale>[
  Locale('en', 'GB'),
  Locale('en', 'US'),
  Locale('en', 'AU'),
  Locale('en', 'CA'),
  Locale('en', 'IE'),
  Locale('en', 'IN'),
  Locale('en', 'NZ'),
  Locale('en', 'SG'),
  Locale('en', 'ZA'),
];

const _fallbackLocale = Locale('en', 'GB');

/// Picks the first English device locale Pebble supports, else UK English.
Locale resolvePebbleLocale(List<Locale>? deviceLocales) {
  for (final locale in deviceLocales ?? const <Locale>[]) {
    if (locale.languageCode != 'en') continue;
    for (final supported in pebbleSupportedLocales) {
      if (supported.countryCode == locale.countryCode) return supported;
    }
  }
  return _fallbackLocale;
}

/// Loads intl's date symbols and points `DateFormat` at [locale], so
/// `DateFormat.jm()` and friends match the Material widgets.
Future<void> configurePebbleDateLocale(Locale locale) async {
  await initializeDateFormatting();
  applyPebbleDateLocale(locale);
}

void applyPebbleDateLocale(Locale locale) {
  Intl.defaultLocale = Intl.canonicalizedLocale(locale.toString());
}
