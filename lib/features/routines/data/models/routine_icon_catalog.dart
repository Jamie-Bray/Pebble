import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

class RoutineVisualIcon {
  final String key;
  final String label;
  final IconData icon;
  final bool isPremium;

  const RoutineVisualIcon({
    required this.key,
    required this.label,
    required this.icon,
    this.isPremium = false,
  });
}

class RoutineIconCatalog {
  const RoutineIconCatalog._();

  static const String defaultKey = 'sparkles';

  static const List<RoutineVisualIcon> all = [
    RoutineVisualIcon(
      key: defaultKey,
      label: 'Pebble',
      icon: LucideIcons.sparkles,
      isPremium: false,
    ),
    RoutineVisualIcon(
      key: 'shield-check',
      label: 'Shield',
      icon: LucideIcons.shieldCheck,
      isPremium: true,
    ),
    RoutineVisualIcon(
      key: 'house',
      label: 'Home',
      icon: LucideIcons.house,
      isPremium: true,
    ),
    RoutineVisualIcon(
      key: 'moon',
      label: 'Moon',
      icon: LucideIcons.moon,
      isPremium: true,
    ),
    RoutineVisualIcon(
      key: 'clock',
      label: 'Clock',
      icon: LucideIcons.clock,
      isPremium: true,
    ),
    RoutineVisualIcon(
      key: 'bell',
      label: 'Bell',
      icon: LucideIcons.bell,
      isPremium: true,
    ),
    RoutineVisualIcon(
      key: 'leaf',
      label: 'Leaf',
      icon: LucideIcons.leaf,
      isPremium: true,
    ),
    RoutineVisualIcon(
      key: 'camera',
      label: 'Camera',
      icon: LucideIcons.camera,
      isPremium: true,
    ),
    RoutineVisualIcon(
      key: 'circle-check',
      label: 'Check Circle',
      icon: LucideIcons.circleCheck,
      isPremium: true,
    ),
    RoutineVisualIcon(
      key: 'key',
      label: 'Key',
      icon: LucideIcons.key,
      isPremium: true,
    ),
    RoutineVisualIcon(
      key: 'check',
      label: 'Check',
      icon: LucideIcons.check,
      isPremium: true,
    ),
    RoutineVisualIcon(
      key: 'pin',
      label: 'Pin',
      icon: LucideIcons.pin,
      isPremium: true,
    ),
    RoutineVisualIcon(
      key: 'alarm-check',
      label: 'Alarm Check',
      icon: LucideIcons.alarmClockCheck,
      isPremium: true,
    ),
    RoutineVisualIcon(
      key: 'sun',
      label: 'Day',
      icon: LucideIcons.sun,
      isPremium: true,
    ),
    RoutineVisualIcon(
      key: 'coffee',
      label: 'Coffee',
      icon: LucideIcons.coffee,
      isPremium: true,
    ),
    RoutineVisualIcon(
      key: 'utensils',
      label: 'Food',
      icon: LucideIcons.utensils,
      isPremium: true,
    ),
    RoutineVisualIcon(
      key: 'book',
      label: 'Read',
      icon: LucideIcons.book,
      isPremium: true,
    ),
    RoutineVisualIcon(
      key: 'dumbbell',
      label: 'Workout',
      icon: LucideIcons.dumbbell,
      isPremium: true,
    ),
    RoutineVisualIcon(
      key: 'bath',
      label: 'Bath',
      icon: LucideIcons.bath,
      isPremium: true,
    ),
    RoutineVisualIcon(
      key: 'briefcase',
      label: 'Work',
      icon: LucideIcons.briefcase,
      isPremium: true,
    ),
    RoutineVisualIcon(
      key: 'car',
      label: 'Travel',
      icon: LucideIcons.car,
      isPremium: true,
    ),
    RoutineVisualIcon(
      key: 'zap',
      label: 'Energy',
      icon: LucideIcons.zap,
      isPremium: true,
    ),
    RoutineVisualIcon(
      key: 'brain',
      label: 'Focus',
      icon: LucideIcons.brain,
      isPremium: true,
    ),
    RoutineVisualIcon(
      key: 'trophy',
      label: 'Goal',
      icon: LucideIcons.trophy,
      isPremium: true,
    ),
    RoutineVisualIcon(
      key: 'shopping-bag',
      label: 'Errand',
      icon: LucideIcons.shoppingBag,
      isPremium: true,
    ),
    RoutineVisualIcon(
      key: 'heart',
      label: 'Health',
      icon: LucideIcons.heart,
      isPremium: true,
    ),
  ];

  static final Map<String, RoutineVisualIcon> _byKey = {
    for (final icon in all) icon.key: icon,
  };

  static const Map<String, String> _legacyAliases = {
    '': defaultKey,
    'default': defaultKey,
    'pebble': defaultKey,
    'sparkle': defaultKey,
    'check': 'circle-check',
    'trend': 'check',
    'trending-up': 'check',
    'gem': 'shield-check',
    'star': 'shield-check',
    'users': 'house',
    'palette': 'leaf',
    'calendar': 'clock',
    'bell-ring': 'bell',
    // Legacy emoji values from prior customization flows.
    '☀️': 'moon',
    '🌙': 'moon',
    '🌿': 'leaf',
    '🌅': 'clock',
    '📄': 'check',
    '🔥': 'bell',
    '🔮': 'shield-check',
    '💫': defaultKey,
    '🌸': 'leaf',
    '⭐': 'shield-check',
    '🧘': 'shield-check',
    '🎯': 'shield-check',
    '📈': 'check',
    '🧩': 'check',
    '✨': defaultKey,
    '🪴': 'leaf',
    '🪨': defaultKey,
    '🏖️': 'clock',
    '📋': 'check',
    '✅': 'circle-check',
    '🏠': 'house',
    '✈️': 'clock',
  };

  static RoutineVisualIcon resolve(String? storedValue) {
    final normalized = _normalize(storedValue);
    return _byKey[normalized] ?? _byKey[defaultKey]!;
  }

  static String sanitizeForStorage(
    String? storedValue, {
    required bool hasPremiumAccess,
  }) {
    final resolved = resolve(storedValue);
    if (!hasPremiumAccess && resolved.isPremium) {
      return defaultKey;
    }
    return resolved.key;
  }

  static String _normalize(String? raw) {
    final value = (raw ?? '').trim().toLowerCase();
    if (_byKey.containsKey(value)) return value;
    return _legacyAliases[value] ?? value;
  }
}
