import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/core/ui/pebble_confirmation_sheet.dart';
import 'package:pebble_routines/core/ui/pebble_photo_gallery_viewer.dart';
import 'package:pebble_routines/features/account_backup/providers/account_status_mapper.dart';
import 'package:pebble_routines/features/history/ui/routine_run_detail_screen.dart';
import 'package:pebble_routines/features/history/providers/routine_history_vm.dart';
import 'package:pebble_routines/features/routines/list/providers/routine_list_provider.dart';
import 'package:pebble_routines/features/routines/execution/data/models/routine_session.dart';
import 'package:pebble_routines/features/routines/execution/data/services/routine_session_proof_storage.dart';
import 'package:pebble_routines/features/subscription/providers/premium_feature_policy_provider.dart';
import 'package:pebble_routines/core/theme/colors.dart';
import 'package:pebble_routines/core/ui/zen_error_view.dart';
import 'package:pebble_routines/core/ui/pebble_navigation.dart';

// History View Modes
enum HistoryViewMode { timeline, vault }

final historyViewModeProvider = StateProvider<HistoryViewMode>(
  (ref) => HistoryViewMode.timeline,
);

final historySearchQueryProvider = StateProvider<String?>((ref) => null);
final isSearchVisibleProvider = StateProvider<bool>((ref) => false);

class StyledHistoryScreen extends ConsumerStatefulWidget {
  const StyledHistoryScreen({super.key});

  @override
  ConsumerState<StyledHistoryScreen> createState() =>
      _StyledHistoryScreenState();
}

class _StyledHistoryScreenState extends ConsumerState<StyledHistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final runsAsync = ref.watch(routineHistoryVmProvider);
    final routinesAsync = ref.watch(routineListProvider);
    final incomingQuery = ref.watch(historySearchQueryProvider);
    final viewMode = ref.watch(historyViewModeProvider);
    final isSearchVisible = ref.watch(isSearchVisibleProvider);
    final proofStorage = ref.watch(routineSessionProofStorageProvider);
    final premiumPolicy = ref.watch(premiumFeaturePolicyProvider);
    final backupStatus = ref.watch(accountStatusPresentationProvider);

    return runsAsync.when(
      loading: () => const _ThemeScaffold(
        child: Center(child: CircularProgressIndicator.adaptive()),
      ),
      error: (e, _) => _ThemeScaffold(
        child: ZenErrorView(message: 'Could not load history: $e'),
      ),
      data: (runs) {
        return routinesAsync.when(
          loading: () => const _ThemeScaffold(
            child: Center(child: CircularProgressIndicator.adaptive()),
          ),
          error: (e, _) => _ThemeScaffold(
            child: ZenErrorView(message: 'Could not load routines: $e'),
          ),
          data: (routines) {
            final byId = <String, Routine>{
              for (final r in routines) r.id.toString(): r,
              for (final r in routines)
                if (r.cloudId != null && r.cloudId!.isNotEmpty) r.cloudId!: r,
            };

            if (incomingQuery != null &&
                _searchController.text != incomingQuery) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!context.mounted) return;
                _searchController.text = incomingQuery;
                setState(() {});
                ref.read(historySearchQueryProvider.notifier).state = null;
              });
            }

            final query = _searchController.text.trim().toLowerCase();
            final filtered =
                query.isEmpty
                      ? runs
                      : runs.where((run) {
                          final title = run.routineTitle.toLowerCase();
                          return title.contains(query);
                        }).toList()
                  ..sort((a, b) => b.finishedAt.compareTo(a.finishedAt));

            return _ThemeScaffold(
              child: Column(
                children: [
                  _buildUnifiedHeader(
                    context,
                    ref,
                    isSearchVisible,
                    filtered.length,
                  ),

                  Expanded(
                    child: viewMode == HistoryViewMode.timeline
                        ? _buildTimelineView(
                            filtered,
                            byId,
                            proofStorage,
                            premiumPolicy,
                            backupStatus,
                          )
                        : _buildVaultView(filtered, byId, proofStorage),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildUnifiedHeader(
    BuildContext context,
    WidgetRef ref,
    bool isSearchVisible,
    int count,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HistoryHeader(
          subtitle: _historySubtitle(count: count),
          isSearchVisible: isSearchVisible,
          onSearchTap: () {
            HapticFeedback.lightImpact();
            ref.read(isSearchVisibleProvider.notifier).state = !isSearchVisible;
            if (!isSearchVisible) {
              _searchFocusNode.requestFocus();
            } else {
              _searchController.clear();
              setState(() {});
            }
          },
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 4),
          child: _buildSegmentedToggle(ref),
        ),
        if (isSearchVisible)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 14, 24, 6),
            child: _SlimSearchField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              onChanged: (_) => setState(() {}),
            ),
          ),
      ],
    );
  }

  Widget _buildSegmentedToggle(WidgetRef ref) {
    final mode = ref.watch(historyViewModeProvider);
    final foundation = context.darkFoundation;

    return Container(
      height: 36,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: foundation.textPrimary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          _ToggleItem(
            label: 'Timeline',
            isSelected: mode == HistoryViewMode.timeline,
            onTap: () {
              HapticFeedback.lightImpact();
              ref.read(historyViewModeProvider.notifier).state =
                  HistoryViewMode.timeline;
            },
          ),
          _ToggleItem(
            label: 'Photo Vault',
            isSelected: mode == HistoryViewMode.vault,
            onTap: () {
              HapticFeedback.lightImpact();
              ref.read(historyViewModeProvider.notifier).state =
                  HistoryViewMode.vault;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineView(
    List<RoutineRun> filtered,
    Map<String, Routine> byId,
    RoutineSessionProofStorage proofStorage,
    PremiumFeaturePolicy premiumPolicy,
    AccountStatusPresentation backupStatus,
  ) {
    if (filtered.isEmpty) return _buildEmptyState(context, premiumPolicy);

    final grouped = _groupRuns(filtered);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(routineHistoryVmProvider);
      },
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 124),
        itemCount: grouped.length + (backupStatus.showRunSyncState ? 0 : 1),
        itemBuilder: (context, index) {
          if (index >= grouped.length) {
            return const _HistoryBackupFooter();
          }

          final section = grouped.keys.elementAt(index);
          final runsInSection = grouped[section]!;
          if (runsInSection.isEmpty) return const SizedBox.shrink();

          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _HistoryDateLabel(title: _sectionLabel(section)),
                const SizedBox(height: 10),
                ...runsInSection.map(
                  (run) => _HistoryCard(
                    run: run,
                    routine: byId[run.routineId],
                    proofStorage: proofStorage,
                    showSyncState: backupStatus.showRunSyncState,
                    onDismiss: () => _confirmDismissRun(context, ref, run),
                    onManage: () {
                      HapticFeedback.mediumImpact();
                      _showManageRunSheet(context, ref, run, proofStorage);
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildVaultView(
    List<RoutineRun> runs,
    Map<String, Routine> byId,
    RoutineSessionProofStorage proofStorage,
  ) {
    return FutureBuilder<List<_VaultPhoto>>(
      future: _collectAvailableVaultPhotos(runs, byId, proofStorage),
      builder: (context, snapshot) {
        final allPhotos = snapshot.data ?? const <_VaultPhoto>[];
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator.adaptive());
        }
        if (allPhotos.isEmpty) return _buildVaultEmptyState();

        return GridView.builder(
          padding: const EdgeInsets.all(24),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1,
          ),
          itemCount: allPhotos.length,
          itemBuilder: (context, index) {
            return _VaultGridItem(
              photo: allPhotos[index],
              photos: allPhotos,
              photoIndex: index,
              proofStorage: proofStorage,
            );
          },
        );
      },
    );
  }

  Future<List<_VaultPhoto>> _collectAvailableVaultPhotos(
    List<RoutineRun> runs,
    Map<String, Routine> byId,
    RoutineSessionProofStorage proofStorage,
  ) async {
    final allPhotos = <_VaultPhoto>[];
    for (final run in runs) {
      if (run.stepCompletionData == null) continue;
      try {
        final data = jsonDecode(run.stepCompletionData!);
        final steps = data['steps'] as List<dynamic>? ?? [];
        for (var i = 0; i < steps.length; i++) {
          final step = steps[i];
          final completedAtStr = step['completedAt'] as String?;
          final completedAt = completedAtStr != null
              ? DateTime.parse(completedAtStr)
              : run.finishedAt;

          var stepLabel = 'Step ${i + 1}';
          if (step['label'] != null && (step['label'] as String).isNotEmpty) {
            stepLabel = step['label'];
          } else {
            final r = byId[run.routineId];
            if (r != null) {
              try {
                final rSteps = jsonDecode(r.stepsJson) as List<dynamic>;
                if (i < rSteps.length) {
                  stepLabel = rSteps[i]['label'] ?? 'Step ${i + 1}';
                }
              } catch (_) {}
            }
          }

          final proofAssets = step['proofAssets'] as List<dynamic>? ?? [];
          if (proofAssets.isNotEmpty) {
            for (final rawAsset in proofAssets) {
              if (rawAsset is! Map) continue;
              final asset = RoutineSessionProofAsset.fromJson(
                Map<String, dynamic>.from(rawAsset),
              );
              if (asset.localRelativePath.isEmpty) continue;
              if (!await _proofExists(
                proofStorage,
                asset.localRelativePath,
                asset,
              )) {
                continue;
              }
              allPhotos.add(
                _VaultPhoto(
                  path: asset.localRelativePath,
                  asset: asset,
                  timestamp: asset.capturedAt,
                  label: stepLabel,
                  run: run,
                ),
              );
            }
            continue;
          }

          final photos = step['photos'] as List<dynamic>? ?? [];
          for (final photoPath in photos) {
            final path = photoPath.toString();
            if (!await _proofExists(proofStorage, path, null)) continue;
            allPhotos.add(
              _VaultPhoto(
                path: path,
                asset: null,
                timestamp: completedAt,
                label: stepLabel,
                run: run,
              ),
            );
          }
        }
      } catch (_) {
        // Skip malformed run data.
      }
    }

    allPhotos.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return allPhotos;
  }

  Future<bool> _proofExists(
    RoutineSessionProofStorage proofStorage,
    String storedPath,
    RoutineSessionProofAsset? asset,
  ) async {
    final file = asset == null
        ? await proofStorage.resolveStoredFile(storedPath)
        : await proofStorage.resolveProofAssetFile(asset);
    return file != null && file.existsSync();
  }

  Widget _buildVaultEmptyState() {
    final foundation = context.darkFoundation;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            LucideIcons.cameraOff,
            size: 38,
            color: foundation.textPrimary.withValues(alpha: 0.24),
          ),
          const SizedBox(height: 16),
          Text(
            'No proof photos yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w500,
              color: foundation.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Photos you capture during routines will gather here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.3,
                fontWeight: FontWeight.w300,
                color: foundation.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Groups runs into sections with robust date math (handles month/year changes).
  Map<HistorySection, List<RoutineRun>> _groupRuns(List<RoutineRun> runs) {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final startOfYesterday = startOfToday.subtract(const Duration(days: 1));
    final startOfTwoDaysAgo = startOfToday.subtract(const Duration(days: 2));
    final startOfThreeDaysAgo = startOfToday.subtract(const Duration(days: 3));

    final map = <HistorySection, List<RoutineRun>>{}
      ..[HistorySection.today] = []
      ..[HistorySection.yesterday] = []
      ..[HistorySection.twoDaysAgo] = []
      ..[HistorySection.threeDaysAgo] = []
      ..[HistorySection.older] = [];

    for (final run in runs) {
      final t = run.finishedAt;
      final day = DateTime(t.year, t.month, t.day);

      if (day == startOfToday) {
        map[HistorySection.today]!.add(run);
      } else if (day == startOfYesterday) {
        map[HistorySection.yesterday]!.add(run);
      } else if (day == startOfTwoDaysAgo) {
        map[HistorySection.twoDaysAgo]!.add(run);
      } else if (day == startOfThreeDaysAgo) {
        map[HistorySection.threeDaysAgo]!.add(run);
      } else {
        map[HistorySection.older]!.add(run);
      }
    }
    return map;
  }

  String _sectionLabel(HistorySection s) {
    switch (s) {
      case HistorySection.today:
        return 'TODAY';
      case HistorySection.yesterday:
        return 'YESTERDAY';
      case HistorySection.twoDaysAgo:
        return '2 DAYS AGO';
      case HistorySection.threeDaysAgo:
        return '3 DAYS AGO';
      case HistorySection.older:
        return 'OLDER';
    }
  }

  Widget _buildEmptyState(BuildContext context, PremiumFeaturePolicy policy) {
    final foundation = context.darkFoundation;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 48, color: foundation.textMuted),
            const SizedBox(height: 18),
            Text(
              'No routine runs yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: foundation.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              policy.canUseCloudBackup
                  ? 'Completed routine runs will appear here and back up quietly.'
                  : 'Complete a routine and Pebble will keep the record here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                fontWeight: FontWeight.w300,
                color: foundation.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _historySubtitle({required int count}) {
    final noun = count == 1 ? 'routine run' : 'routine runs';
    return '$count $noun saved';
  }

  Future<void> _showManageRunSheet(
    BuildContext context,
    WidgetRef ref,
    RoutineRun run,
    RoutineSessionProofStorage proofStorage,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.darkFoundation.surfaceLow,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        final foundation = sheetContext.darkFoundation;
        final photoRefs = _collectRunPhotoRefs(run);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      color: foundation.borderSubtle,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  run.routineTitle.isEmpty ? 'Routine run' : run.routineTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: foundation.textPrimary,
                  ),
                ),
                const SizedBox(height: 18),
                _HistorySheetAction(
                  icon: LucideIcons.history,
                  label: 'View routine run',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => RoutineRunDetailScreen(run: run),
                      ),
                    );
                  },
                ),
                if (photoRefs.isNotEmpty)
                  _HistorySheetAction(
                    icon: LucideIcons.images,
                    label: 'View photos',
                    onTap: () async {
                      Navigator.pop(sheetContext);
                      await _openRunPhotoGallery(
                        context,
                        run,
                        proofStorage,
                        photoRefs,
                      );
                    },
                  ),
                _HistorySheetAction(
                  icon: LucideIcons.trash2,
                  label: 'Delete this routine run',
                  isDestructive: true,
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await _showDeleteRunConfirmation(context, ref, run);
                  },
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    child: const Text('Cancel'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showDeleteRunConfirmation(
    BuildContext context,
    WidgetRef ref,
    RoutineRun run,
  ) async {
    final confirmed = await _confirmDeleteRun(context, run);
    if (confirmed) {
      await deleteSingleRun(ref, run.id);
    }
  }

  Future<bool> _confirmDeleteRun(BuildContext context, RoutineRun run) async {
    final confirmed = await showPebbleConfirmationSheet(
      context: context,
      title: 'Delete this routine run?',
      body: 'This will permanently remove this routine run from your history.',
      confirmLabel: 'Delete routine run',
      isDestructive: true,
    );
    return confirmed == true;
  }

  Future<bool> _confirmDismissRun(
    BuildContext context,
    WidgetRef ref,
    RoutineRun run,
  ) async {
    final confirmed = await _confirmDeleteRun(context, run);
    if (confirmed) {
      await deleteSingleRun(ref, run.id);
    }
    return confirmed;
  }

  Future<void> _openRunPhotoGallery(
    BuildContext context,
    RoutineRun run,
    RoutineSessionProofStorage proofStorage,
    List<_RunPhotoRef> photoRefs,
  ) async {
    final availableRefs = <_RunPhotoRef>[];
    for (final photo in photoRefs) {
      final file = photo.asset == null
          ? await proofStorage.resolveStoredFile(photo.path)
          : await proofStorage.resolveProofAssetFile(photo.asset!);
      if (file != null && file.existsSync()) {
        availableRefs.add(photo);
      }
    }
    if (availableRefs.isEmpty) {
      return;
    }

    final galleryPhotos = availableRefs
        .map(
          (photo) => PebbleGalleryPhoto(
            id: photo.path,
            storedPath: photo.path,
            title: photo.label,
            subtitle: DateFormat.yMMMd().add_jm().format(photo.timestamp),
          ),
        )
        .toList();

    if (!context.mounted) {
      return;
    }
    return PebblePhotoGalleryViewer.open(
      context,
      photos: galleryPhotos,
      initialIndex: 0,
      resolvePhotoFile: (storedPath) async {
        _RunPhotoRef? match;
        for (final ref in availableRefs) {
          if (ref.path == storedPath) {
            match = ref;
            break;
          }
        }
        if (match?.asset != null) {
          return proofStorage.resolveProofAssetFile(match!.asset!);
        }
        return proofStorage.resolveStoredFile(storedPath);
      },
      bottomBuilder: (context, index) {
        return SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => RoutineRunDetailScreen(run: run),
                ),
              );
            },
            icon: const Icon(LucideIcons.history, size: 18),
            label: const Text('View routine run'),
          ),
        );
      },
    );
  }
}

/* ---------- Small UI helpers (frosted elements + section/card widgets) ---------- */

class _ThemeScaffold extends StatelessWidget {
  const _ThemeScaffold({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;

    return Material(
      color: foundation.bgBase,
      child: Container(
        decoration: BoxDecoration(color: foundation.bgBase),
        child: child,
      ),
    );
  }
}

class _SlimSearchField extends StatelessWidget {
  const _SlimSearchField({
    required this.controller,
    required this.focusNode,
    this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: foundation.borderSubtle)),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: TextStyle(color: foundation.textPrimary),
        decoration: InputDecoration(
          prefixIcon: Icon(
            LucideIcons.search,
            size: 18,
            color: foundation.textMuted,
          ),
          hintText: 'Search routines…',
          hintStyle: TextStyle(color: foundation.textMuted),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }
}

class _HistoryHeader extends StatelessWidget {
  const _HistoryHeader({
    required this.subtitle,
    required this.isSearchVisible,
    required this.onSearchTap,
  });

  final String subtitle;
  final bool isSearchVisible;
  final VoidCallback onSearchTap;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 26, 24, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Text(
                    'History',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSerifDisplay(
                      fontSize: 34,
                      height: 1,
                      fontWeight: FontWeight.w400,
                      color: foundation.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: isSearchVisible ? 'Close search' : 'Search',
                  visualDensity: VisualDensity.compact,
                  onPressed: onSearchTap,
                  icon: Icon(
                    isSearchVisible ? LucideIcons.x : LucideIcons.search,
                    color: foundation.textSecondary,
                    size: 20,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w300,
                color: foundation.textMuted,
                letterSpacing: 0.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToggleItem extends StatelessWidget {
  const _ToggleItem({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? foundation.surfaceLow : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w500 : FontWeight.w400,
              letterSpacing: 0.1,
              color: isSelected ? foundation.textPrimary : foundation.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryDateLabel extends StatelessWidget {
  const _HistoryDateLabel({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 8, 2, 0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 1.2,
          color: foundation.textPrimary.withValues(alpha: 0.22),
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.run,
    required this.routine,
    required this.proofStorage,
    required this.showSyncState,
    required this.onDismiss,
    required this.onManage,
  });

  final RoutineRun run;
  final Routine? routine;
  final RoutineSessionProofStorage proofStorage;
  final bool showSyncState;
  final Future<bool> Function() onDismiss;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final r = routine;
    final foundation = context.darkFoundation;

    final syncState = showSyncState ? _syncStateForRun(run) : null;
    final title = run.routineTitle.trim().isEmpty
        ? 'Deleted routine'
        : run.routineTitle.trim();
    final stepCount = _runStepCount(run);
    final completedStepCount = _runCompletedStepCount(run);
    final isComplete = stepCount > 0 && completedStepCount >= stepCount;
    final accent = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Dismissible(
        key: ValueKey('history-run-${run.id}'),
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) => onDismiss(),
        background: const _HistoryDismissBackground(),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => RoutineRunDetailScreen(run: run),
              ),
            );
          },
          onLongPress: onManage,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: foundation.surfaceLow,
                border: Border.all(color: foundation.borderSubtle),
              ),
              child: Stack(
                children: [
                  Positioned(
                    left: 0,
                    top: 16,
                    bottom: 16,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 3,
                      decoration: BoxDecoration(
                        color: accent.withValues(
                          alpha: isComplete ? 0.62 : 0.26,
                        ),
                        borderRadius: const BorderRadius.horizontal(
                          right: Radius.circular(2),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 14, 18),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _HistoryRunTimeBlock(time: run.finishedAt),
                        Container(
                          width: 1,
                          height: 36,
                          margin: const EdgeInsets.symmetric(horizontal: 18),
                          color: foundation.borderSubtle,
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: -0.1,
                                  height: 1.18,
                                  color: foundation.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              _HistoryRunBadges(
                                run: run,
                                proofStorage: proofStorage,
                                syncState: syncState,
                                completedSteps: completedStepCount,
                                totalSteps: stepCount,
                              ),
                              if (r == null) ...[
                                const SizedBox(height: 5),
                                Text(
                                  'Routine deleted',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: foundation.textMuted,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Icon(
                          LucideIcons.chevronRight,
                          size: 16,
                          color: foundation.textPrimary.withValues(alpha: 0.18),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryRunTimeBlock extends StatelessWidget {
  const _HistoryRunTimeBlock({required this.time});

  final DateTime time;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    return SizedBox(
      width: 68,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: Text(
                DateFormat('h:mm').format(time),
                maxLines: 1,
                textAlign: TextAlign.right,
                style: GoogleFonts.dmSerifDisplay(
                  fontSize: 26,
                  height: 1,
                  fontWeight: FontWeight.w400,
                  color: foundation.textPrimary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            DateFormat('a').format(time).toLowerCase(),
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.8,
              color: foundation.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryDismissBackground extends StatelessWidget {
  const _HistoryDismissBackground();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 18),
        color: cs.error.withValues(alpha: 0.12),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: cs.error, shape: BoxShape.circle),
          child: const Icon(LucideIcons.trash2, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}

enum _HistorySyncState { synced, pending, attention }

_HistorySyncState? _syncStateForRun(RoutineRun run) {
  if (run.syncStatus == 'synced') {
    return _HistorySyncState.synced;
  }
  if (run.ownerUserId != null &&
      run.ownerUserId!.isNotEmpty &&
      run.syncStatus != 'localOnly') {
    final normalized = run.syncStatus.toLowerCase();
    if (normalized.contains('failed') || normalized.contains('error')) {
      return _HistorySyncState.attention;
    }
    return _HistorySyncState.pending;
  }
  return null;
}

class _HistorySyncPill extends StatelessWidget {
  const _HistorySyncPill({required this.state});

  final _HistorySyncState state;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final accent = switch (state) {
      _HistorySyncState.synced => Color.lerp(
        cs.primary,
        const Color(0xFF8DA174),
        0.45,
      )!,
      _HistorySyncState.pending => const Color(0xFFD99B55),
      _HistorySyncState.attention => cs.error,
    };
    final icon = switch (state) {
      _HistorySyncState.synced => LucideIcons.cloud,
      _HistorySyncState.pending => LucideIcons.cloudUpload,
      _HistorySyncState.attention => LucideIcons.cloudAlert,
    };

    return Tooltip(
      message: switch (state) {
        _HistorySyncState.synced => 'Backed up',
        _HistorySyncState.pending => 'Queued for backup',
        _HistorySyncState.attention => 'Backup needs attention',
      },
      child: Padding(
        padding: const EdgeInsets.only(left: 2),
        child: Icon(icon, size: 15, color: accent),
      ),
    );
  }
}

class _HistoryRunBadges extends StatelessWidget {
  const _HistoryRunBadges({
    required this.run,
    required this.proofStorage,
    required this.syncState,
    required this.completedSteps,
    required this.totalSteps,
  });

  final RoutineRun run;
  final RoutineSessionProofStorage proofStorage;
  final _HistorySyncState? syncState;
  final int completedSteps;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: _existingRunPhotoCount(run, proofStorage),
      builder: (context, snapshot) {
        final photoCount = snapshot.data ?? 0;
        return Wrap(
          spacing: 6,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (totalSteps > 0)
              _HistoryCompletionChip(
                completedSteps: completedSteps,
                totalSteps: totalSteps,
              ),
            if (syncState == _HistorySyncState.attention)
              _HistorySyncPill(state: syncState!),
            if (photoCount > 0) _HistoryPhotoCount(count: photoCount),
          ],
        );
      },
    );
  }
}

class _HistoryCompletionChip extends StatelessWidget {
  const _HistoryCompletionChip({
    required this.completedSteps,
    required this.totalSteps,
  });

  final int completedSteps;
  final int totalSteps;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    final cs = Theme.of(context).colorScheme;
    final isComplete = totalSteps > 0 && completedSteps >= totalSteps;
    final accent = isComplete ? cs.primary : foundation.textMuted;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 4,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: isComplete ? 0.8 : 0.42),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '$completedSteps of $totalSteps steps',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w400,
            letterSpacing: 0.1,
            color: foundation.textMuted,
          ),
        ),
      ],
    );
  }
}

class _HistoryPhotoCount extends StatelessWidget {
  const _HistoryPhotoCount({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    return Tooltip(
      message: '$count retained photo${count == 1 ? '' : 's'}',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$count photo${count == 1 ? '' : 's'}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w400,
              letterSpacing: 0.1,
              color: foundation.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _HistorySheetAction extends StatelessWidget {
  const _HistorySheetAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    final cs = Theme.of(context).colorScheme;
    final color = isDestructive ? cs.error : foundation.textPrimary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Row(
            children: [
              Icon(icon, size: 19, color: color),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
              Icon(
                LucideIcons.chevronRight,
                size: 16,
                color: foundation.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryBackupFooter extends StatelessWidget {
  const _HistoryBackupFooter();

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 16, 2, 24),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'History is only kept for 2 days',
              style: TextStyle(
                fontSize: 11,
                height: 1.2,
                fontWeight: FontWeight.w300,
                letterSpacing: 0.1,
                color: foundation.textPrimary.withValues(alpha: 0.22),
              ),
            ),
          ),
          const SizedBox(width: 16),
          TextButton(
            onPressed: () => context.push('/account-hub'),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              foregroundColor: cs.primary.withValues(alpha: 0.78),
              textStyle: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.1,
              ),
            ),
            child: const Text('Back up with Premium'),
          ),
        ],
      ),
    );
  }
}

class _RunPhotoRef {
  const _RunPhotoRef({
    required this.path,
    required this.asset,
    required this.timestamp,
    required this.label,
  });

  final String path;
  final RoutineSessionProofAsset? asset;
  final DateTime timestamp;
  final String label;
}

class _VaultPhoto {
  final String path;
  final RoutineSessionProofAsset? asset;
  final DateTime timestamp;
  final String label;
  final RoutineRun run;

  _VaultPhoto({
    required this.path,
    required this.asset,
    required this.timestamp,
    required this.label,
    required this.run,
  });
}

class _VaultGridItem extends StatelessWidget {
  const _VaultGridItem({
    required this.photo,
    required this.photos,
    required this.photoIndex,
    required this.proofStorage,
  });
  final _VaultPhoto photo;
  final List<_VaultPhoto> photos;
  final int photoIndex;
  final RoutineSessionProofStorage proofStorage;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: () async {
        HapticFeedback.lightImpact();
        await _showGallery(context);
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(color: cs.surfaceContainerHighest),
          child: Stack(
            fit: StackFit.expand,
            children: [
              _VaultStoredPhotoView(
                proofStorage: proofStorage,
                storedPath: photo.path,
                asset: photo.asset,
                missing: _buildMissingPhotoPlaceholder(cs),
              ),

              // Overlays
              _buildGradientOverlay(),
              _buildInfoOverlay(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMissingPhotoPlaceholder(ColorScheme cs) {
    return Container(
      color: const Color(0xFF4A5D4E).withValues(alpha: 0.2), // Moss green tint
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.imageOff, color: Color(0xFF4A5D4E), size: 24),
          SizedBox(height: 8),
          Text(
            'Photo unavailable',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF4A5D4E),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradientOverlay() {
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withValues(alpha: 0.54), // Subtle, legible overlay
            ],
            stops: const [0.5, 1.0],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoOverlay(BuildContext context) {
    return Positioned(
      left: 12,
      right: 12,
      bottom: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            DateFormat.jm().format(photo.timestamp),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          Text(
            photo.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showGallery(BuildContext context) {
    final galleryPhotos = photos
        .map(
          (item) => PebbleGalleryPhoto(
            id: item.path,
            storedPath: item.path,
            title: item.label,
            subtitle:
                '${DateFormat.yMMMd().format(item.timestamp)} • ${DateFormat.jm().format(item.timestamp)}',
          ),
        )
        .toList();

    return PebblePhotoGalleryViewer.open(
      context,
      photos: galleryPhotos,
      initialIndex: photoIndex,
      resolvePhotoFile: (storedPath) async {
        _VaultPhoto? match;
        for (final item in photos) {
          if (item.path == storedPath) {
            match = item;
            break;
          }
        }
        if (match?.asset != null) {
          return proofStorage.resolveProofAssetFile(match!.asset!);
        }
        return proofStorage.resolveStoredFile(storedPath);
      },
      bottomBuilder: (context, index) {
        final current = photos[index];
        return SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => RoutineRunDetailScreen(run: current.run),
                ),
              );
            },
            icon: const Icon(LucideIcons.history, size: 18),
            label: const Text('View Routine Run'),
          ),
        );
      },
    );
  }
}

// ignore: unused_element
class _HeroPhotoView extends StatelessWidget {
  const _HeroPhotoView({required this.photo, required this.proofStorage});
  final _VaultPhoto photo;
  final RoutineSessionProofStorage proofStorage;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // Dismissible background
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(color: Colors.transparent),
          ),

          // Image / Content
          Center(
            child: Hero(
              tag: photo.path,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: _VaultStoredPhotoView(
                        proofStorage: proofStorage,
                        storedPath: photo.path,
                        asset: photo.asset,
                        fit: BoxFit.contain,
                        missing: Container(
                          height: 300,
                          width: double.infinity,
                          color: Colors.white.withValues(alpha: 0.05),
                          child: Icon(
                            LucideIcons.imageOff,
                            color: Colors.white.withValues(alpha: 0.3),
                            size: 48,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      photo.label,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${DateFormat.yMMMd().format(photo.timestamp)} • ${DateFormat.jm().format(photo.timestamp)}',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 32),
                    FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                RoutineRunDetailScreen(run: photo.run),
                          ),
                        );
                      },
                      icon: const Icon(LucideIcons.history, size: 18),
                      label: const Text('View Routine Run'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white.withValues(alpha: 0.1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: PebbleBackChrome(),
          ),
        ],
      ),
    );
  }
}

class _VaultStoredPhotoView extends StatelessWidget {
  const _VaultStoredPhotoView({
    required this.proofStorage,
    required this.storedPath,
    required this.asset,
    required this.missing,
    this.fit,
  });

  final RoutineSessionProofStorage proofStorage;
  final String storedPath;
  final RoutineSessionProofAsset? asset;
  final Widget missing;
  final BoxFit? fit;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<File?>(
      future: asset == null
          ? proofStorage.resolveStoredFile(storedPath)
          : proofStorage.resolveProofAssetFile(asset!),
      builder: (context, snapshot) {
        final file = snapshot.data;
        if (file != null && file.existsSync()) {
          return Image.file(file, fit: fit ?? BoxFit.cover);
        }
        return missing;
      },
    );
  }
}

/* ---------- Private helpers ---------- */

enum HistorySection { today, yesterday, twoDaysAgo, threeDaysAgo, older }

int _runStepCount(RoutineRun run) {
  final data = _decodeRunCompletionData(run);
  final effectiveSteps = data?['effectiveSteps'];
  if (effectiveSteps is List && effectiveSteps.isNotEmpty) {
    return effectiveSteps.length;
  }
  final steps = data?['steps'];
  if (steps is List) {
    return steps.length;
  }
  return 0;
}

int _runCompletedStepCount(RoutineRun run) {
  final data = _decodeRunCompletionData(run);
  final steps = data?['steps'];
  if (steps is! List || steps.isEmpty) {
    return _runStepCount(run);
  }

  var completed = 0;
  for (final rawStep in steps) {
    if (rawStep is! Map) {
      continue;
    }
    final step = Map<String, dynamic>.from(rawStep);
    final skipped = step['skipped'] == true;
    final explicitlyCompleted = step['completed'] == true;
    final hasCompletionTime =
        DateTime.tryParse(step['completedAt']?.toString() ?? '') != null;
    if (!skipped && (explicitlyCompleted || hasCompletionTime)) {
      completed++;
    }
  }

  return completed;
}

Map<String, dynamic>? _decodeRunCompletionData(RoutineRun run) {
  final raw = run.stepCompletionData;
  if (raw == null || raw.isEmpty) {
    return null;
  }
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
  } catch (_) {
    return null;
  }
  return null;
}

List<_RunPhotoRef> _collectRunPhotoRefs(RoutineRun run) {
  final data = _decodeRunCompletionData(run);
  final stepData = data?['steps'] as List<dynamic>? ?? const [];
  final refs = <_RunPhotoRef>[];

  for (var i = 0; i < stepData.length; i++) {
    final rawStep = stepData[i];
    if (rawStep is! Map) {
      continue;
    }
    final step = Map<String, dynamic>.from(rawStep);
    final label = (step['label']?.toString().trim().isNotEmpty ?? false)
        ? step['label'].toString()
        : 'Step ${i + 1}';
    final completedAt =
        DateTime.tryParse(step['completedAt']?.toString() ?? '') ??
        run.finishedAt;

    final proofAssets = step['proofAssets'] as List<dynamic>? ?? const [];
    for (final rawAsset in proofAssets) {
      if (rawAsset is! Map) {
        continue;
      }
      final asset = RoutineSessionProofAsset.fromJson(
        Map<String, dynamic>.from(rawAsset),
      );
      if (asset.localRelativePath.isEmpty) {
        continue;
      }
      refs.add(
        _RunPhotoRef(
          path: asset.localRelativePath,
          asset: asset,
          timestamp: asset.capturedAt,
          label: label,
        ),
      );
    }

    if (proofAssets.isNotEmpty) {
      continue;
    }

    final photos = step['photos'] as List<dynamic>? ?? const [];
    for (final rawPath in photos) {
      final path = rawPath.toString();
      if (path.isEmpty) {
        continue;
      }
      refs.add(
        _RunPhotoRef(
          path: path,
          asset: null,
          timestamp: completedAt,
          label: label,
        ),
      );
    }
  }

  return refs;
}

Future<int> _existingRunPhotoCount(
  RoutineRun run,
  RoutineSessionProofStorage proofStorage,
) async {
  final refs = _collectRunPhotoRefs(run);
  var count = 0;
  for (final ref in refs) {
    final file = ref.asset == null
        ? await proofStorage.resolveStoredFile(ref.path)
        : await proofStorage.resolveProofAssetFile(ref.asset!);
    if (file != null && file.existsSync()) {
      count++;
    }
  }
  return count;
}
