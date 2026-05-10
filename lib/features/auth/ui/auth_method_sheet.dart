import 'package:flutter/material.dart';
void showAuthMethodSheet(BuildContext context) {
  final colorScheme = Theme.of(context).colorScheme;

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return Container(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 30),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colorScheme.outline.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              const Text(
                'Why sign in?',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Sign in to use your account on this device. Backup and sync are available with Personal Premium.',
                style: TextStyle(
                  fontSize: 15,
                  color: colorScheme.onSurface.withValues(alpha: 0.72),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 18),
              const _AuthMethodFact(
                title: 'Email OTP',
                body:
                    'Get a one-time code by email and sign in without a password.',
              ),
              const _AuthMethodFact(
                title: 'Google',
                body: 'Use your Google account for faster sign-in.',
              ),
              const _AuthMethodFact(
                title: 'Apple (coming soon)',
                body: 'Apple sign-in will be available in a future update.',
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _AuthMethodFact extends StatelessWidget {
  const _AuthMethodFact({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: colorScheme.outline.withValues(alpha: 0.12),
          ),
          color: colorScheme.surfaceContainerLow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              body,
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurface.withValues(alpha: 0.70),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
