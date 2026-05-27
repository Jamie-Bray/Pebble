import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pebble_routines/features/auth/providers/auth_state_provider.dart';

Future<void> showEmailOtpSheet(BuildContext context, WidgetRef ref) {
  final emailController = TextEditingController();
  final codeController = TextEditingController();
  var otpRequested = false;
  var isBusy = false;
  String? inlineError;

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
                    if (inlineError != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        inlineError!,
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.error,
                          height: 1.35,
                        ),
                      ),
                    ],
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
                        onPressed: isBusy
                            ? null
                            : () async {
                                final email = emailController.text.trim();
                                final code = codeController.text.trim();
                                if (!otpRequested && !_looksLikeEmail(email)) {
                                  setState(
                                    () => inlineError =
                                        'Enter a valid email address.',
                                  );
                                  return;
                                }
                                if (otpRequested && code.isEmpty) {
                                  setState(
                                    () => inlineError =
                                        'Enter the one-time code from your email.',
                                  );
                                  return;
                                }

                                setState(() {
                                  isBusy = true;
                                  inlineError = null;
                                });

                                final authController = ref.read(
                                  authControllerProvider.notifier,
                                );
                                var success = false;
                                if (!otpRequested) {
                                  success = await authController
                                      .requestEmailOtp(email);
                                  if (context.mounted) {
                                    setState(() {
                                      isBusy = false;
                                      if (success) {
                                        otpRequested = true;
                                      } else {
                                        inlineError = _authError(ref);
                                      }
                                    });
                                  }
                                  return;
                                }

                                success = await authController.verifyEmailOtp(
                                  email: email,
                                  token: code,
                                );
                                if (!context.mounted) return;
                                if (success) {
                                  Navigator.of(context).pop();
                                  return;
                                }
                                setState(() {
                                  isBusy = false;
                                  inlineError = _authError(ref);
                                });
                              },
                        child: isBusy
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator.adaptive(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                            : Text(
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
  ).whenComplete(() {
    emailController.dispose();
    codeController.dispose();
  });
}

bool _looksLikeEmail(String value) {
  return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
}

String _authError(WidgetRef ref) {
  return ref.read(authControllerProvider).errorMessage ??
      'We could not complete sign-in. Please try again.';
}
