import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/core/ui/pebble_confirmation_sheet.dart';
import 'package:pebble_routines/core/ui/pebble_photo_gallery_viewer.dart';
import 'package:pebble_routines/features/history/ui/routine_run_detail_screen.dart';
import 'package:pebble_routines/features/history/providers/routine_history_vm.dart';
import 'package:pebble_routines/features/routines/list/providers/routine_list_provider.dart';
import 'package:pebble_routines/features/routines/data/models/routine_icon_catalog.dart';
import 'package:pebble_routines/features/routines/execution/data/models/routine_session.dart';
import 'package:pebble_routines/features/routines/execution/data/services/routine_session_proof_storage.dart';
import 'package:pebble_routines/features/subscription/domain/user_tier.dart';
import 'package:pebble_routines/features/subscription/providers/subscription_provider.dart';
import 'package:pebble_routines/features/subscription/ui/pebble_paywall.dart';
import 'package:pebble_routines/core/theme/colors.dart';
import 'package:pebble_routines/core/ui/zen_error_view.dart';
import 'package:pebble_routines/core/ui/zen_components.dart';
import 'package:pebble_routines/core/ui/pebble_navigation.dart';

// Provider for tracking collapsed sections
// History View Modes
enum HistoryViewMode { timeline, vault }

final historyViewModeProvider = StateProvider<HistoryViewMode>(
  (ref) => HistoryViewMode.timeline,
);

final historySearchQueryProvider = StateProvider<String?>((ref) => null);
final isSearchVisibleProvider = StateProvider<bool>((ref) => false);

final collapsedSectionsProvider =
    StateNotifierProvider<CollapsedSectionsNotifier, Set<HistorySection>>((
      ref,
    ) {
      return CollapsedSectionsNotifier();
    });

class CollapsedSectionsNotifier extends StateNotifier<Set<HistorySection>> {
  CollapsedSectionsNotifier() : super(<HistorySection>{});

  void toggleSection(HistorySection section) {
    final newState = Set<HistorySection>.from(state);
    if (newState.contains(section)) {
      newState.remove(section);
    } else {
      newState.add(section);
    }
    state = newState;
  }

  bool isCollapsed(HistorySection section) {
    return state.contains(section);
  }
}

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
    final collapsedSections = ref.watch(collapsedSectionsProvider);
    final incomingQuery = ref.watch(historySearchQueryProvider);
    final viewMode = ref.watch(historyViewModeProvider);
    final isSearchVisible = ref.watch(isSearchVisibleProvider);
    final proofStorage = ref.watch(routineSessionProofStorageProvider);
    final userTier = ref.watch(subscriptionProvider);

    return runsAsync.when(
      loading: () => const _ThemeScaffold(
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => _ThemeScaffold(
        child: ZenErrorView(message: 'Could not load history: $e'),
      ),
      data: (runs) {
        return routinesAsync.when(
          loading: () => const _ThemeScaffold(
            child: Center(child: CircularProgressIndicator()),
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
                  // Unified Header with Toggle and Search
                  _buildUnifiedHeader(
                    context,
                    ref,
                    isSearchVisible,
                    filtered.length,
                    userTier,
                    filtered,
                  ),

                  // Content
                  Expanded(
                    child: viewMode == HistoryViewMode.timeline
                        ? _buildTimelineView(
                            filtered,
                            byId,
                            collapsedSections,
                            proofStorage,
                            userTier,
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
    UserTier userTier,
    List<RoutineRun> visibleRuns,
  ) {
    final foundation = context.darkFoundation;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ZenScreenHeader(
          title: 'History',
          subtitle: _historySubtitle(
            count: count,
            userTier: userTier,
            runs: visibleRuns,
          ),
          actions: [
            IconButton(
              tooltip: 'Search',
              onPressed: () {
                HapticFeedback.lightImpact();
                ref.read(isSearchVisibleProvider.notifier).state =
                    !isSearchVisible;
                if (!isSearchVisible) {
                  _searchFocusNode.requestFocus();
                } else {
                  _searchController.clear();
                  setState(() {});
                }
              },
              icon: Icon(
                LucideIcons.search,
                color: foundation.textSecondary,
                size: 24,
              ),
            ),
            IconButton(
              tooltip: 'Delete all history',
              onPressed: () => _showDeleteAllDialog(context, ref),
              icon: Icon(
                LucideIcons.trash2,
                color: foundation.textSecondary,
                size: 24,
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [_buildSegmentedToggle(ref)],
          ),
        ),
        // Search line with increased margin and Lucide style
        if (isSearchVisible)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
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
      height: 42,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: foundation.surfaceHigh.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: foundation.borderSubtle),
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
    Set<HistorySection> collapsedSections,
    RoutineSessionProofStorage proofStorage,
    UserTier userTier,
  ) {
    if (filtered.isEmpty) return _buildEmptyState(context, userTier);

    final grouped = _groupRuns(filtered);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(routineHistoryVmProvider);
      },
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 128),
        itemCount: grouped.length + (userTier.hasCloud ? 0 : 1),
        itemBuilder: (context, index) {
          if (index >= grouped.length) {
            return const _HistoryBackupFooter();
          }

          final section = grouped.keys.elementAt(index);
          final runsInSection = grouped[section]!;
          if (runsInSection.isEmpty) return const SizedBox.shrink();
          final isCollapsed = collapsedSections.contains(section);

          return Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SectionHeader(
                  title: _sectionLabel(section),
                  count: runsInSection.length,
                  isCollapsed: isCollapsed,
                  onTap: () {
                    ref
                        .read(collapsedSectionsProvider.notifier)
                        .toggleSection(section);
                  },
                ),
                if (!isCollapsed) ...[
                  const SizedBox(height: 6),
                  ...runsInSection.map(
                    (run) => _HistoryCard(
                      run: run,
                      routine: byId[run.routineId],
                      proofStorage: proofStorage,
                      showSyncState: userTier.hasCloud,
                      onManage: () {
                        HapticFeedback.mediumImpact();
                        _showManageRunSheet(context, ref, run, proofStorage);
                      },
                    ),
                  ),
                ],
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
    // Extract all photos from runs
    final allPhotos = <_VaultPhoto>[];
    for (final run in runs) {
      if (run.stepCompletionData == null) continue;
      try {
        final data = jsonDecode(run.stepCompletionData!);
        final steps = data['steps'] as List<dynamic>? ?? [];
        for (var i = 0; i < steps.length; i++) {
          final step = steps[i];
          final photos = step['photos'] as List<dynamic>? ?? [];
          final completedAtStr = step['completedAt'] as String?;
          final completedAt = completedAtStr != null
              ? DateTime.parse(completedAtStr)
              : run.finishedAt;

          // Try to get step label from completion data if available, otherwise from routine
          String stepLabel = 'Step ${i + 1}';
          if (step['label'] != null && (step['label'] as String).isNotEmpty) {
            stepLabel = step['label'];
          } else {
            // Fallback to title from the routine for this index
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
              if (asset.localRelativePath.isEmpty) {
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

          for (final photoPath in photos) {
            allPhotos.add(
              _VaultPhoto(
                path: photoPath as String,
                asset: null,
                timestamp: completedAt,
                label: stepLabel,
                run: run,
              ),
            );
          }
        }
      } catch (e) {
        // Skip malformed data
      }
    }

    if (allPhotos.isEmpty) return _buildVaultEmptyState();

    // Sort by timestamp newest first
    allPhotos.sort((a, b) => b.timestamp.compareTo(a.timestamp));

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
  }

  Widget _buildVaultEmptyState() {
    final foundation = context.darkFoundation;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.cameraOff, size: 48, color: foundation.textMuted),
          const SizedBox(height: 16),
          Text(
            'Photo Vault is Empty',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: foundation.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              'Capture photos during your routines to see them here for instant peace of mind.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: foundation.textSecondary),
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

  Widget _buildEmptyState(BuildContext context, UserTier userTier) {
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
                fontSize: 22,
                fontWeight: FontWeight.w500,
                color: foundation.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              userTier.hasCloud
                  ? 'Completed routine runs will appear here and back up quietly.'
                  : 'Complete a routine and Pebble will keep the record here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                height: 1.35,
                color: foundation.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _historySubtitle({
    required int count,
    required UserTier userTier,
    required List<RoutineRun> runs,
  }) {
    final noun = count == 1 ? 'routine run' : 'routine runs';
    if (!userTier.hasCloud) {
      return '$count $noun saved on this device';
    }

    final hasFailed = runs.any((run) {
      final normalized = run.syncStatus.toLowerCase();
      return normalized.contains('failed') || normalized.contains('error');
    });
    if (hasFailed) {
      return '$count $noun saved - backup needs attention';
    }

    final hasPending = runs.any((run) {
      final normalized = run.syncStatus.toLowerCase();
      return normalized != 'synced' && normalized != 'localonly';
    });
    if (hasPending) {
      return '$count $noun saved - backup in progress';
    }

    return '$count $noun backed up for supported restore';
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

  Future<void> _showDeleteAllDialog(BuildContext context, WidgetRef ref) async {
    final confirmed = await showPebbleConfirmationSheet(
      context: context,
      title: 'Delete all history?',
      body:
          'This will permanently erase your entire history including all stored vault photos. This action cannot be undone.',
      confirmLabel: 'Delete all history',
      isDestructive: true,
    );
    if (confirmed == true) {
      await deleteAllRuns(ref);
    }
  }

  Future<void> _showDeleteRunConfirmation(
    BuildContext context,
    WidgetRef ref,
    RoutineRun run,
  ) async {
    final confirmed = await showPebbleConfirmationSheet(
      context: context,
      title: 'Delete this routine run?',
      body: 'This will permanently remove this routine run from your history.',
      confirmLabel: 'Delete routine run',
      isDestructive: true,
    );
    if (confirmed == true) {
      await deleteSingleRun(ref, run.id);
    }
  }

  Future<void> _openRunPhotoGallery(
    BuildContext context,
    RoutineRun run,
    RoutineSessionProofStorage proofStorage,
    List<_RunPhotoRef> photoRefs,
  ) {
    final galleryPhotos = photoRefs
        .map(
          (photo) => PebbleGalleryPhoto(
            id: photo.path,
            storedPath: photo.path,
            title: photo.label,
            subtitle: DateFormat.yMMMd().add_jm().format(photo.timestamp),
          ),
        )
        .toList();

    return PebblePhotoGalleryViewer.open(
      context,
      photos: galleryPhotos,
      initialIndex: 0,
      resolvePhotoFile: (storedPath) async {
        _RunPhotoRef? match;
        for (final ref in photoRefs) {
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
            borderRadius: BorderRadius.circular(15),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: foundation.shadowSoft,
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected
                  ? foundation.textPrimary
                  : foundation.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    required this.count,
    required this.isCollapsed,
    required this.onTap,
  });

  final String title;
  final int count;
  final bool isCollapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 2),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.9,
                        color: foundation.textMuted,
                      ),
                    ),
                  ),
                  Text(
                    '$count run${count == 1 ? '' : 's'}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: foundation.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: isCollapsed ? -0.25 : 0.0,
                    duration: const Duration(milliseconds: 220),
                    child: Icon(
                      LucideIcons.chevronDown,
                      color: foundation.textMuted,
                      size: 18,
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

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.run,
    required this.routine,
    required this.proofStorage,
    required this.showSyncState,
    required this.onManage,
  });

  final RoutineRun run;
  final Routine? routine;
  final RoutineSessionProofStorage proofStorage;
  final bool showSyncState;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) {
    final r = routine;
    final cs = Theme.of(context).colorScheme;
    final foundation = context.darkFoundation;

    final routineIcon = RoutineIconCatalog.resolve(r?.emoji);
    final syncState = showSyncState ? _syncStateForRun(run) : null;
    final title = run.routineTitle.trim().isEmpty
        ? 'Deleted routine'
        : run.routineTitle.trim();
    final stepCount = _runStepCount(run);
    final metadata = [
      DateFormat.jm().format(run.finishedAt),
      if (stepCount > 0) '$stepCount step${stepCount == 1 ? '' : 's'}',
    ].join(' - ');

    final storedHex = r?.colorHex;
    final bubbleColor = Color(
      _ensureArgb(storedHex ?? cs.primary.toARGB32()),
    ).withValues(alpha: r == null ? 0.72 : 0.9);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => RoutineRunDetailScreen(run: run)),
          );
        },
        onLongPress: onManage,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: foundation.surfaceLow,
                border: Border.all(color: foundation.borderSubtle),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: bubbleColor.withValues(alpha: 0.14),
                    ),
                    alignment: Alignment.center,
                    child: Icon(
                      r == null ? LucideIcons.history : routineIcon.icon,
                      size: 18,
                      color: bubbleColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            height: 1.18,
                            color: foundation.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          metadata,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: foundation.textSecondary,
                          ),
                        ),
                        if (r == null) ...[
                          const SizedBox(height: 3),
                          Text(
                            'Routine deleted',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: foundation.textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  _HistoryRowTrailing(
                    run: run,
                    proofStorage: proofStorage,
                    syncState: syncState,
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
        _HistorySyncState.pending => 'Backup in progress',
        _HistorySyncState.attention => 'Backup needs attention',
      },
      child: Container(
        width: 28,
        height: 28,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.1),
          shape: BoxShape.circle,
          border: Border.all(color: accent.withValues(alpha: 0.16)),
        ),
        child: Icon(icon, size: 15, color: accent),
      ),
    );
  }
}

class _HistoryRowTrailing extends StatelessWidget {
  const _HistoryRowTrailing({
    required this.run,
    required this.proofStorage,
    required this.syncState,
  });

  final RoutineRun run;
  final RoutineSessionProofStorage proofStorage;
  final _HistorySyncState? syncState;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: _existingRunPhotoCount(run, proofStorage),
      builder: (context, snapshot) {
        final photoCount = snapshot.data ?? 0;
        if (photoCount == 0 && syncState == null) {
          return const SizedBox(width: 4);
        }
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (syncState != null) _HistorySyncPill(state: syncState!),
            if (photoCount > 0) ...[
              if (syncState != null) const SizedBox(width: 6),
              _HistoryPhotoCount(count: photoCount),
            ],
          ],
        );
      },
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
          Icon(LucideIcons.camera, size: 13, color: foundation.textSecondary),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: foundation.textSecondary,
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
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 24),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: foundation.surfaceLow.withValues(alpha: 0.62),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: foundation.borderSubtle),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: cs.primary.withValues(alpha: 0.12),
                ),
                child: Icon(LucideIcons.cloud, size: 17, color: cs.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Premium can back up supported history for restore.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.25,
                    fontWeight: FontWeight.w600,
                    color: foundation.textSecondary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => context.push(
                  premiumRoute(source: PremiumEntrySource.backup),
                ),
                child: const Text('Learn more'),
              ),
            ],
          ),
        ),
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
      resolvePhotoFile: proofStorage.resolveStoredFile,
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

int _ensureArgb(int argbOrRgb) {
  // If upper 8 bits (alpha) are zero, add 0xFF alpha.
  if ((argbOrRgb >> 24) == 0x00) return 0xFF000000 | argbOrRgb;
  return argbOrRgb;
}
