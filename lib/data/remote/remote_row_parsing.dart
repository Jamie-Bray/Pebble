import 'package:flutter/foundation.dart';

/// Parses each Supabase row on its own, so one malformed row is logged and
/// skipped instead of failing the whole fetch (and with it, a restore).
List<T> parseRemoteRows<T>(
  List<dynamic> rows,
  T Function(Map<String, dynamic> json) parse, {
  required String table,
}) {
  final parsed = <T>[];
  for (final row in rows.whereType<Map>()) {
    try {
      parsed.add(parse(Map<String, dynamic>.from(row)));
    } catch (error) {
      debugPrint('Skipped malformed $table row ${row['id']}: $error');
    }
  }
  return parsed;
}
