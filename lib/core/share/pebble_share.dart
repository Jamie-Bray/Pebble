import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import 'package:pebble_routines/core/ui/zen_notifications.dart';

/// Opens the phone's share sheet with some text. The person chooses where it
/// goes (Messages, WhatsApp, email, notes) and sends it themselves.
class PebbleShare {
  const PebbleShare();

  /// [context] should be the tapped control: iPads anchor the share popover
  /// to it.
  Future<void> shareText(
    BuildContext context,
    String text, {
    String? subject,
  }) async {
    final box = context.findRenderObject();
    final origin = box is RenderBox && box.hasSize
        ? box.localToGlobal(Offset.zero) & box.size
        : null;
    try {
      await SharePlus.instance.share(
        ShareParams(text: text, subject: subject, sharePositionOrigin: origin),
      );
    } catch (_) {
      if (!context.mounted) return;
      ZenNotifications.showInfo(
        context,
        message: "Couldn't open sharing. Try again.",
      );
    }
  }
}

final pebbleShareProvider = Provider<PebbleShare>((ref) => const PebbleShare());
