import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pebble_routines/features/auth/providers/auth_state_provider.dart';

Future<void> showEmailOtpSheet(BuildContext context, WidgetRef ref) {
  final emailController = TextEditingController();
  final codeController = TextEditingController();
  var otpRequested = false;

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      final colorScheme = Theme.of(context).colorScheme;
      return StatefulBuilder(
        builder: (context, setState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(30),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
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
                    Text(
                      otpRequested ? 'Enter your code' : 'Sign in with email',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      otpRequested
                          ? 'We sent a one-time code to ${emailController.text.trim()}.'
                          : 'Sign in to use your account on this device.',
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.onSurface.withValues(alpha: 0.72),
                      ),
                    ),
                    const SizedBox(height: 18),
                    TextField(
                      controller: emailController,
                      keyboardType: TextInputType.emailAddress,
                      enabled: !otpRequested,
                      decoration: const InputDecoration(
                        labelText: 'Email address',
                      ),
                    ),
                    if (otpRequested) ...[
                      const SizedBox(height: 12),
                      TextField(
                        controller: codeController,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'One-time code',
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () async {
                          if (!otpRequested) {
                            await ref
                                .read(authControllerProvider.notifier)
                                .requestEmailOtp(emailController.text.trim());
                            if (context.mounted) {
                              setState(() => otpRequested = true);
                            }
                            return;
                          }

                          await ref
                              .read(authControllerProvider.notifier)
                              .verifyEmailOtp(
                                email: emailController.text.trim(),
                                token: codeController.text.trim(),
                              );
                          if (context.mounted) {
                            Navigator.of(context).pop();
                          }
                        },
                        child: Text(
                          otpRequested ? 'Complete sign-in' : 'Send code',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}
