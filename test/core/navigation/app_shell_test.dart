import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/core/navigation/app_shell.dart';
import 'package:pebble_routines/core/theme/colors.dart';
import 'package:pebble_routines/core/theme/theme_provider.dart';
import 'package:pebble_routines/features/account_backup/providers/account_backup_ui_provider.dart';
import 'package:pebble_routines/features/account_backup/providers/account_status_mapper.dart';
import 'package:pebble_routines/features/history/providers/routine_history_vm.dart';
import 'package:pebble_routines/features/routines/execution/data/repositories/routine_session_repository.dart';
import 'package:pebble_routines/features/routines/execution/data/services/routine_session_proof_storage.dart';
import 'package:pebble_routines/features/routines/list/providers/routine_list_provider.dart';
import 'package:pebble_routines/features/settings/data/player_settings_provider.dart';
import 'package:pebble_routines/features/subscription/domain/user_tier.dart';
import 'package:pebble_routines/features/subscription/providers/premium_feature_policy_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/premium_policy_test_utils.dart';

void main() {
  Future<void> pumpShell(
    WidgetTester tester, {
    required List<RoutineRun> runs,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          currentThemeDataProvider.overrideWithValue(
            AppTheme.fromId(ThemeId.highNoon),
          ),
          currentColorThemeProvider.overrideWithValue(ThemeId.highNoon),
          routineListProvider.overrideWith((ref) => Stream.value(<Routine>[])),
          routineHistoryVmProvider.overrideWith(
            (ref) => Stream.value([...runs]),
          ),
          activeRoutineSessionsProvider.overrideWith(
            (ref) => Stream.value(const []),
          ),
          routineSessionProofStorageProvider.overrideWithValue(
            _NoopProofStorage(),
          ),
          premiumFeaturePolicyProvider.overrideWithValue(
            premiumFeaturePolicyForTier(UserTier.personalFree),
          ),
          accountStatusPresentationProvider.overrideWithValue(_presentation),
          accountBackupChipStateProvider.overrideWithValue(
            const AccountBackupChipState.hidden(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.fromId(ThemeId.highNoon),
          home: const AppShell(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('first run with no routines and no history hides the bar', (
    tester,
  ) async {
    await pumpShell(tester, runs: const []);

    expect(find.text('Start with one routine.'), findsOneWidget);
    expect(find.byKey(const ValueKey('app_shell_bottom_bar')), findsNothing);
  });

  testWidgets('History stays reachable after every routine is deleted', (
    tester,
  ) async {
    final finishedAt = DateTime(2026, 10, 3, 8);
    await pumpShell(
      tester,
      runs: [
        RoutineRun(
          id: 'run-1',
          routineId: '1',
          routineTitle: 'Morning reset',
          finishedAt: finishedAt,
          stepCompletionData: null,
          ownerUserId: null,
          syncStatus: 'localOnly',
          lastSyncedAt: null,
          syncMetadataJson: null,
          updatedAt: finishedAt,
        ),
      ],
    );

    expect(find.text('Start with one routine.'), findsOneWidget);
    expect(find.byKey(const ValueKey('app_shell_bottom_bar')), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

const _presentation = AccountStatusPresentation(
  planLabel: 'Free',
  title: 'Saved on this phone',
  body: '',
  statusLabel: 'Backup is off',
  historyLabel: '2 days',
  limitChips: [],
  featureHighlights: [],
  primaryAction: AccountStatusAction.none,
  primaryActionLabel: null,
  secondaryAction: AccountStatusAction.none,
  secondaryActionLabel: null,
  supportingDetail: null,
  tone: AccountStatusTone.neutral,
  icon: LucideIcons.cloudOff,
  isSyncRunning: false,
  showRunSyncState: false,
  showPremiumNote: false,
);

class _NoopProofStorage implements RoutineSessionProofStorage {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
