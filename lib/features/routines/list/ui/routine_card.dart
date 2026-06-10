import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pebble_routines/core/database/local_db.dart';
import 'package:pebble_routines/core/theme/colors.dart';
import 'package:pebble_routines/data/repositories/routine_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pebble_routines/features/routines/data/models/routine_icon_catalog.dart';

class RoutineCard extends ConsumerStatefulWidget {
  final Routine routine;
  final bool isPinned;
  final Color themeColor;
  final VoidCallback onStart;
  final VoidCallback onStats;
  final VoidCallback onEdit;
  final VoidCallback onColor;
  final VoidCallback? onReorder;
  final VoidCallback? onReminder;
  final VoidCallback? onMore;
  final VoidCallback? onQuickAdd;

  const RoutineCard({
    super.key,
    required this.routine,
    required this.isPinned,
    required this.themeColor,
    required this.onStart,
    required this.onStats,
    required this.onEdit,
    required this.onColor,
    this.onReorder,
    this.onReminder,
    this.onMore,
    this.onQuickAdd,
  });

  @override
  ConsumerState<RoutineCard> createState() => _RoutineCardState();
}

class _RoutineCardState extends ConsumerState<RoutineCard> {
  int _getStepCount(Routine routine) {
    try {
      if (routine.stepsJson.isEmpty) return 0;
      final steps = jsonDecode(routine.stepsJson) as List<dynamic>;
      return steps.length;
    } catch (_) {
      return 0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final foundation = context.darkFoundation;

    return _Pressable(
      onTap: () {
        widget.onStart();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: foundation.surfaceLow,
          border: Border.all(color: foundation.borderSubtle, width: 1),
          boxShadow: [
            BoxShadow(
              color: foundation.shadowSoft,
              blurRadius: 18,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: foundation.surfaceHigh.withValues(alpha: 0.18),
                  ),
                ),
              ),

              // Card content
              Padding(
                padding: const EdgeInsets.all(16),
                child: _buildHeaderRow(foundation),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderRow(PebbleDarkFoundation foundation) {
    final routineIcon = RoutineIconCatalog.resolve(widget.routine.emoji);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _IconBubble(icon: routineIcon.icon, color: widget.themeColor),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.routine.title,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: foundation.textPrimary,
                        height: 1.1,
                      ),
                    ),
                  ),
                  if (widget.isPinned)
                    const Padding(
                      padding: EdgeInsets.only(left: 6.0),
                      child: Icon(
                        LucideIcons.pin,
                        size: 14,
                        color: Colors.amber,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(
                    _buildMetaText(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                      color: foundation.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    LucideIcons.clock,
                    size: 10,
                    color: foundation.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Consumer(
                    builder: (context, ref, child) {
                      final latestRun = ref.watch(
                        latestRoutineRunProvider(widget.routine.id),
                      );
                      return latestRun.when(
                        data: (run) {
                          if (run == null) {
                            return Text(
                              'Not run yet',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w400,
                                color: foundation.textMuted,
                              ),
                            );
                          }
                          final diff = DateTime.now().difference(
                            run.finishedAt,
                          );
                          String timeText;
                          if (diff.inMinutes < 1) {
                            timeText = 'just now';
                          } else if (diff.inHours < 1) {
                            timeText = '${diff.inMinutes}m ago';
                          } else if (diff.inDays < 1) {
                            timeText = '${diff.inHours}h ago';
                          } else {
                            timeText = DateFormat(
                              'MMM d',
                            ).format(run.finishedAt);
                          }
                          return Text(
                            'Last ran: $timeText',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                              color: foundation.textMuted,
                            ),
                          );
                        },
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        _Pressable(
          onTap: () {
            widget.onMore?.call();
          },
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: foundation.surfaceHigh,
              border: Border.all(color: foundation.borderSubtle, width: 1),
            ),
            child: Icon(
              LucideIcons.ellipsisVertical,
              size: 20,
              color: foundation.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  String _buildMetaText() {
    final steps = _getStepCount(widget.routine);
    return '$steps step${steps == 1 ? '' : 's'}';
  }
}

// --- Subcomponents ---

class _IconBubble extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _IconBubble({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.25), color.withValues(alpha: 0.6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Center(child: Icon(icon, size: 18, color: Colors.white)),
    );
  }
}

class _Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _Pressable({required this.child, required this.onTap});

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 0.96,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(_) => _controller.forward();
  void _onTapUp(_) {
    _controller.reverse();
    widget.onTap();
  }

  void _onTapCancel() => _controller.reverse();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) =>
            Transform.scale(scale: _scale.value, child: child),
        child: widget.child,
      ),
    );
  }
}
