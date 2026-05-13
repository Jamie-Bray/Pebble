enum UserTier {
  personalFree,
  personalPremium,
  pebbleHousehold,
  workspace,
  growth,
  enterprise,
}

extension UserTierExtension on UserTier {
  bool get isFree => this == UserTier.personalFree;

  bool get isHomePlan =>
      this == UserTier.personalFree ||
      this == UserTier.personalPremium ||
      this == UserTier.pebbleHousehold;

  bool get hasCloud => this != UserTier.personalFree;

  bool get isBusiness =>
      this == UserTier.workspace ||
      this == UserTier.growth ||
      this == UserTier.enterprise;

  bool get hasVaultAccess => true;
  bool get hasPremiumThemes => this != UserTier.personalFree;
  bool get hasWallpapers => this != UserTier.personalFree;

  bool get hasSharedReminders =>
      this == UserTier.personalPremium ||
      this == UserTier.pebbleHousehold ||
      this == UserTier.workspace ||
      this == UserTier.growth ||
      this == UserTier.enterprise;

  int? get maxRoutineCount => isFree ? 3 : null;
  int? get maxStepCount => isFree ? 10 : null;
  Duration? get historyRetentionDuration =>
      isFree ? const Duration(hours: 48) : null;

  int? get maxUsers {
    switch (this) {
      case UserTier.personalFree:
      case UserTier.personalPremium:
        return 1;
      case UserTier.pebbleHousehold:
        return 4;
      case UserTier.workspace:
        return 15;
      case UserTier.growth:
        return 100;
      case UserTier.enterprise:
        return null;
    }
  }

  String get displayName {
    switch (this) {
      case UserTier.personalFree:
        return 'Pebble Personal (Free)';
      case UserTier.personalPremium:
        return 'Personal Premium';
      case UserTier.pebbleHousehold:
        return 'Pebble Household';
      case UserTier.workspace:
        return 'Pebble Workspace';
      case UserTier.growth:
        return 'Pebble Growth';
      case UserTier.enterprise:
        return 'Pebble Enterprise';
    }
  }

  String get priceLabel {
    switch (this) {
      case UserTier.personalFree:
        return 'Free';
      case UserTier.personalPremium:
        return '\u00A30.99/mo';
      case UserTier.pebbleHousehold:
        return '\u00A33.99/mo';
      case UserTier.workspace:
        return '\u00A329/mo';
      case UserTier.growth:
        return '\u00A379/mo';
      case UserTier.enterprise:
        return '\u00A3150/mo+';
    }
  }
}
