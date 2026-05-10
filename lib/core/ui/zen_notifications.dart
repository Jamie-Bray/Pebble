import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pebble_routines/core/theme/colors.dart';

class ZenNotifications {
  static void showSuccess(
    BuildContext context, {
    required String message,
    String? title,
    Duration duration = const Duration(seconds: 3),
  }) {
    _showNotification(
      context,
      message: message,
      title: title,
      type: NotificationType.success,
      duration: duration,
    );
  }

  static void showInfo(
    BuildContext context, {
    required String message,
    String? title,
    Duration duration = const Duration(seconds: 3),
  }) {
    _showNotification(
      context,
      message: message,
      title: title,
      type: NotificationType.info,
      duration: duration,
    );
  }

  static void showWarning(
    BuildContext context, {
    required String message,
    String? title,
    Duration duration = const Duration(seconds: 4),
  }) {
    _showNotification(
      context,
      message: message,
      title: title,
      type: NotificationType.warning,
      duration: duration,
    );
  }

  static void showError(
    BuildContext context, {
    required String message,
    String? title,
    Duration duration = const Duration(seconds: 4),
  }) {
    _showNotification(
      context,
      message: message,
      title: title,
      type: NotificationType.error,
      duration: duration,
    );
  }

  static void _showNotification(
    BuildContext context, {
    required String message,
    String? title,
    required NotificationType type,
    required Duration duration,
  }) {
    // Haptic feedback
    HapticFeedback.lightImpact();

    // Show overlay notification
    final overlay = Overlay.of(context);
    late final OverlayEntry overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (context) => _ZenNotificationOverlay(
        message: message,
        title: title,
        type: type,
        duration: duration,
        onDismiss: () => overlayEntry.remove(),
      ),
    );

    overlay.insert(overlayEntry);
  }
}

enum NotificationType { success, info, warning, error }

class _ZenNotificationOverlay extends StatefulWidget {
  final String message;
  final String? title;
  final NotificationType type;
  final Duration duration;
  final VoidCallback onDismiss;

  const _ZenNotificationOverlay({
    required this.message,
    this.title,
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

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _slideAnimation = Tween<double>(
      begin: -1.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    // Start animation
    _controller.forward();

    // Auto-dismiss
    Future.delayed(widget.duration, () {
      if (mounted) {
        _dismiss();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _dismiss() {
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
    return Positioned(
      top: MediaQuery.of(context).padding.top + 20,
      left: 20,
      right: 20,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _slideAnimation.value * 100),
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
