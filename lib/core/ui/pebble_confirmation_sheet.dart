import 'package:flutter/material.dart';
import 'package:pebble_routines/core/theme/colors.dart';

Future<bool?> showPebbleConfirmationSheet({
  required BuildContext context,
  required String title,
  required String body,
  required String confirmLabel,
  String cancelLabel = 'Cancel',
  bool isDestructive = false,
}) {
  final themeData = Theme.of(context);
  final colorScheme = themeData.colorScheme;
  final foundation = context.darkFoundation;

  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: foundation.surfaceLow,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) {
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
                title,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: foundation.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                body,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.4,
                  color: foundation.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(cancelLabel),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: isDestructive
                      ? FilledButton.styleFrom(
                          backgroundColor: colorScheme.errorContainer,
                          foregroundColor: colorScheme.onErrorContainer,
                        )
                      : null,
                  child: Text(confirmLabel),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
