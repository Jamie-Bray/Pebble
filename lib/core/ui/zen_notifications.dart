import 'dart:async';

import 'package:flutter/material.dart';
import 'package:pebble_routines/core/theme/colors.dart';

class ZenNotifications {
  static void showSuccess(
    BuildContext context, {
    required String message,
    String? title,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 4),
  }) {
    _showNotification(
      context,
      message: message,
      title: title,
      actionLabel: actionLabel,
      onAction: onAction,
      type: NotificationType.success,
      duration: duration,
    );
  }

  static void showInfo(
    BuildContext context, {
    required String message,
    String? title,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 4),
  }) {
    _showNotification(
      context,
      message: message,
      title: title,
      actionLabel: actionLabel,
      onAction: onAction,
      type: NotificationType.info,
      duration: duration,
    );
  }

  static void showWarning(
    BuildContext context, {
    required String message,
    String? title,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 6),
  }) {
    _showNotification(
      context,
      message: message,
      title: title,
      actionLabel: actionLabel,
      onAction: onAction,
      type: NotificationType.warning,
      duration: duration,
    );
  }

  static void showError(
    BuildContext context, {
    required String message,
    String? title,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 6),
  }) {
    _showNotification(
      context,
      message: message,
      title: title,
      actionLabel: actionLabel,
      onAction: onAction,
      type: NotificationType.error,
      duration: duration,
    );
  }

  static void _showNotification(
    BuildContext context, {
    required String message,
    String? title,
    String? actionLabel,
    VoidCallback? onAction,
    required NotificationType type,
    required Duration duration,
  }) {
    // Haptic feedback

    // Show overlay notification
    final overlay = Overlay.of(context);
    var removed = false;
    late final OverlayEntry overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (context) => _ZenNotificationOverlay(
        message: message,
        title: title,
        actionLabel: actionLabel,
        onAction: onAction,
        type: type,
        duration: duration,
        onDismiss: () {
          if (removed) {
            return;
          }
          removed = true;
          overlayEntry.remove();
        },
      ),
    );

    overlay.insert(overlayEntry);
  }
}

enum NotificationType { success, info, warning, error }

class _ZenNotificationOverlay extends StatefulWidget {
  final String message;
  final String? title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final NotificationType type;
  final Duration duration;
  final VoidCallback onDismiss;

  const _ZenNotificationOverlay({
    required this.message,
    this.title,
    this.actionLabel,
    this.onAction,
    required this.type,
    required this.duration,
    required this.onDismiss,
  });

  @override
  State<_ZenNotificationOverlay> createState() =>
      _ZenNotificationOverlayState();
}

class _ZenNotificationOverlayState extends State<_ZenNotificationOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  Timer? _dismissTimer;
  bool _isDismissing = false;

  @override
  void initState() {
    super.initState();
    // Calm and quick: a short slide-up with a fade. No elastic bounce — the
    // notice should arrive like a note, not a springboard.
    _controller = AnimationController(
      duration: const Duration(milliseconds: 240),
      reverseDuration: const Duration(milliseconds: 180),
      vsync: this,
    );

    _slideAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _scaleAnimation = Tween<double>(
      begin: 0.97,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    // Start animation
    _controller.forward();

    // Auto-dismiss
    _dismissTimer = Timer(widget.duration, () {
      if (mounted) {
        _dismiss();
      }
    });
  }

  @override
  void dispose() {
    _dismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _dismiss() {
    if (_isDismissing) {
      return;
    }
    _isDismissing = true;
    _dismissTimer?.cancel();
    _controller.reverse().then((_) {
      widget.onDismiss();
    });
  }

  Color _getAccentColor(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (widget.type) {
      case NotificationType.success:
        return colorScheme.primary;
      case NotificationType.info:
        return colorScheme.secondary;
      case NotificationType.warning:
        return colorScheme.tertiary;
      case NotificationType.error:
        return colorScheme.error;
    }
  }

  IconData _getIcon() {
    switch (widget.type) {
      case NotificationType.success:
        return Icons.check_circle;
      case NotificationType.info:
        return Icons.info;
      case NotificationType.warning:
        return Icons.warning;
      case NotificationType.error:
        return Icons.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Bottom placement: the top of the screen belongs to titles and back
    // buttons, and a banner dropping over them read as an interruption.
    // Down here it behaves like a quiet receipt.
    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 24,
      left: 20,
      right: 20,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _slideAnimation.value * 60),
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: Opacity(
                opacity: _fadeAnimation.value,
                child: _buildNotificationCard(context),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNotificationCard(BuildContext context) {
    final foundation = context.darkFoundation;
    final accent = _getAccentColor(context);
    return Semantics(
      // TalkBack/VoiceOver announce the notice when it appears even though
      // focus stays where the user was working.
      liveRegion: true,
      label: widget.title == null
          ? widget.message
          : '${widget.title}. ${widget.message}',
      child: GestureDetector(
        // A flick downward dismisses, matching where the card now lives.
        onVerticalDragUpdate: (details) {
          if (details.delta.dy > 6) {
            _dismiss();
          }
        },
        child: _buildCardBody(context, foundation, accent),
      ),
    );
  }

  Widget _buildCardBody(
    BuildContext context,
    PebbleDarkFoundation foundation,
    Color accent,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: foundation.surfaceHigh,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: foundation.borderSubtle),
        boxShadow: [
          BoxShadow(
            color: foundation.shadowSoft,
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _dismiss,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Icon with glow effect
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_getIcon(), color: accent, size: 22),
                ),
                const SizedBox(width: 16),
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.title != null) ...[
                        Text(
                          widget.title!,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: foundation.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                      ],
                      Text(
                        widget.message,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: foundation.textSecondary,
                        ),
                      ),
                      if (widget.actionLabel != null &&
                          widget.onAction != null) ...[
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () {
                            widget.onAction!();
                            _dismiss();
                          },
                          child: Text(
                            widget.actionLabel!.toUpperCase(),
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                              color: accent,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Close button
                GestureDetector(
                  onTap: _dismiss,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: foundation.surfaceLow,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.close,
                      color: foundation.textMuted,
                      size: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
