import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pebble_routines/core/theme/pebble_fonts.dart';

/// Runs before every test file.
///
/// The app's fonts are bundled assets that google_fonts loads asynchronously.
/// Left alone, a font can finish loading between a frame's layout and paint,
/// which trips TextPainter's size assertion. Loading every bundled variant
/// once up front (as the app would after its first frames) keeps tests
/// deterministic.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  for (final weight in PebbleFonts.sansWeights) {
    PebbleFonts.sans(fontWeight: weight);
  }
  PebbleFonts.sans(fontStyle: FontStyle.italic);
  PebbleFonts.serif();
  PebbleFonts.serif(fontStyle: FontStyle.italic);
  await GoogleFonts.pendingFonts();
  await testMain();
}
