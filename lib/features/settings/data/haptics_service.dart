import 'package:flutter/services.dart';

class HapticsService {
  static final HapticsService _instance = HapticsService._internal();
  factory HapticsService() => _instance;
  HapticsService._internal();

  bool enabled = true;

  void lightImpact() {
    if (enabled) {
      HapticFeedback.lightImpact();
    }
  }

  void mediumImpact() {
    if (enabled) {
      HapticFeedback.mediumImpact();
    }
  }

  void heavyImpact() {
    if (enabled) {
      HapticFeedback.heavyImpact();
    }
  }

  void selectionClick() {
    if (enabled) {
      HapticFeedback.selectionClick();
    }
  }

  void vibrate() {
    if (enabled) {
      HapticFeedback.vibrate();
    }
  }
}
