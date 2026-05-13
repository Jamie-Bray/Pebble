import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:pebble_routines/core/ui/pebble_navigation.dart';

class LegalAboutScreen extends StatelessWidget {
  const LegalAboutScreen({super.key});

  Future<void> _email(BuildContext context, String address) async {
    final opened = await launchUrl(Uri.parse('mailto:$address'));
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Email us at $address')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: colorScheme.surface,
        appBar: PebbleSubscreenAppBar(
          title: 'About Pebble',
          subtitle: 'Privacy, terms, and account deletion',
          onBack: () => Navigator.of(context).maybePop(),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
              child: Container(
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.48,
                  ),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const TabBar(
                  tabs: [
                    Tab(text: 'Privacy'),
                    Tab(text: 'Terms'),
                    Tab(text: 'Delete'),
                  ],
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                children: [
                  _LegalPage(
                    title: 'Privacy, without the fog.',
                    intro:
                        'Pebble is local-first. Most routine data stays on this device unless you choose account, subscription, or cloud backup features.',
                    sections: const [
                      _LegalSection(
                        icon: LucideIcons.hardDrive,
                        title: 'Local-first by default',
                        body:
                            'Without an account, Pebble stores routines, reminders, history, proof photos, guidance audio, and settings on your device.',
                      ),
                      _LegalSection(
                        icon: LucideIcons.cloud,
                        title: 'Cloud backup is optional',
                        body:
                            'If you sign in, have a paid entitlement, and enable cloud backup, Pebble may back up supported routine data, proof photos, sync records, and account metadata in Supabase.',
                      ),
                      _LegalSection(
                        icon: LucideIcons.fileCheck,
                        title: 'Sensitive content consent',
                        body:
                            'Before cloud backup uploads supported routine data, Pebble asks you to confirm that backup may include private details you chose to add.',
                      ),
                      _LegalSection(
                        icon: LucideIcons.megaphoneOff,
                        title: 'No ads or AI training',
                        body:
                            'Pebble does not sell your personal data, use private routine content for advertising, or use routines, proof photos, or guidance audio to train AI models.',
                      ),
                      _LegalSection(
                        icon: LucideIcons.camera,
                        title: 'Permissions',
                        body:
                            'Camera, photos, microphone, and notifications are used only for proof photos, guidance audio, and reminders you choose to create.',
                      ),
                    ],
                    footer: _OwnerFooter(
                      onPrivacy: () =>
                          _email(context, 'privacy@pebbleroutines.app'),
                      onSupport: () =>
                          _email(context, 'support@pebbleroutines.app'),
                    ),
                  ),
                  _LegalPage(
                    title: 'Using Pebble fairly.',
                    intro:
                        'Pebble is a routine support and reassurance app. It is not a medical, emergency, alarm, workplace safety, legal evidence, or guaranteed archive service.',
                    sections: const [
                      _LegalSection(
                        icon: LucideIcons.userRound,
                        title: 'Accounts',
                        body:
                            'Signing out pauses account-linked features on that device. It does not delete cloud data, cancel subscriptions, or remove local data.',
                      ),
                      _LegalSection(
                        icon: LucideIcons.creditCard,
                        title: 'Subscriptions',
                        body:
                            'App stores handle billing, renewal, cancellation, taxes, payment methods, and refunds under their own terms.',
                      ),
                      _LegalSection(
                        icon: LucideIcons.archive,
                        title: 'Backup limits',
                        body:
                            'Cloud backup reduces some risk but is not permanent archive storage. Keep separate records for anything legally, medically, financially, or operationally important.',
                      ),
                      _LegalSection(
                        icon: LucideIcons.image,
                        title: 'Your content',
                        body:
                            'You own what you create in Pebble. Pebble only processes it as needed to provide, secure, support, maintain, debug, and operate the app.',
                      ),
                      _LegalSection(
                        icon: LucideIcons.shieldAlert,
                        title: 'Fair use',
                        body:
                            'Do not bypass subscription checks, upload harmful content, misuse the service, or upload content you do not have the right to use.',
                      ),
                    ],
                    footer: _OwnerFooter(
                      onPrivacy: () =>
                          _email(context, 'privacy@pebbleroutines.app'),
                      onSupport: () =>
                          _email(context, 'support@pebbleroutines.app'),
                    ),
                  ),
                  _LegalPage(
                    title: 'Deleting your account.',
                    intro:
                        'If you sign in, you can delete your Pebble account from Your account. You can also contact support if you cannot access the app.',
                    sections: const [
                      _LegalSection(
                        icon: LucideIcons.trash2,
                        title: 'What cloud deletion covers',
                        body:
                            'Pebble will delete or irreversibly de-identify cloud account data and cloud backup data associated with the account, except where limited retention is required.',
                      ),
                      _LegalSection(
                        icon: LucideIcons.clock3,
                        title: 'Deletion timing',
                        body:
                            'Active cloud account data is normally deleted within 30 days. Backup copies may remain for up to 90 days before expiry.',
                      ),
                      _LegalSection(
                        icon: LucideIcons.smartphone,
                        title: 'Local data may remain',
                        body:
                            'Account deletion does not necessarily remove routines, history, proof photos, guidance audio, or settings already stored on your device.',
                      ),
                      _LegalSection(
                        icon: LucideIcons.receipt,
                        title: 'Subscriptions are separate',
                        body:
                            'Deleting your account, uninstalling Pebble, or signing out does not cancel app-store subscriptions. Cancel through the relevant app-store settings.',
                      ),
                    ],
                    footer: _DeleteFooter(
                      onSupport: () =>
                          _email(context, 'support@pebbleroutines.app'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegalPage extends StatelessWidget {
  const _LegalPage({
    required this.title,
    required this.intro,
    required this.sections,
    required this.footer,
  });

  final String title;
  final String intro;
  final List<_LegalSection> sections;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 44),
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 30,
            height: 1.05,
            fontWeight: FontWeight.w800,
            color: colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          intro,
          style: TextStyle(
            fontSize: 15,
            height: 1.42,
            color: colorScheme.onSurface.withValues(alpha: 0.68),
          ),
        ),
        const SizedBox(height: 18),
        ...sections.map((section) => _LegalCard(section: section)),
        const SizedBox(height: 8),
        footer,
      ],
    );
  }
}

class _LegalSection {
  const _LegalSection({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;
}

class _LegalCard extends StatelessWidget {
  const _LegalCard({required this.section});

  final _LegalSection section;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: colorScheme.outline.withValues(alpha: 0.10)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(section.icon, size: 20, color: colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  section.title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  section.body,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.42,
                    color: colorScheme.onSurface.withValues(alpha: 0.70),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _OwnerFooter extends StatelessWidget {
  const _OwnerFooter({required this.onPrivacy, required this.onSupport});

  final VoidCallback onPrivacy;
  final VoidCallback onSupport;

  @override
  Widget build(BuildContext context) {
    return _FooterBox(
      title: 'Owner and contact',
      body:
          'Pebble Routines is run by an independent developer in Scotland, United Kingdom. For legal and data-protection purposes, the operator is Jamie Bray trading as Pebble.',
      actions: [
        TextButton(onPressed: onPrivacy, child: const Text('Privacy email')),
        TextButton(onPressed: onSupport, child: const Text('Support email')),
      ],
    );
  }
}

class _DeleteFooter extends StatelessWidget {
  const _DeleteFooter({required this.onSupport});

  final VoidCallback onSupport;

  @override
  Widget build(BuildContext context) {
    return _FooterBox(
      title: 'Need help?',
      body:
          'If you cannot access Your account, email support@pebbleroutines.app from the address linked to your Pebble account if possible.',
      actions: [
        TextButton(onPressed: onSupport, child: const Text('Email support')),
      ],
    );
  }
}

class _FooterBox extends StatelessWidget {
  const _FooterBox({
    required this.title,
    required this.body,
    required this.actions,
  });

  final String title;
  final String body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: TextStyle(
              fontSize: 13,
              height: 1.38,
              color: colorScheme.onSurface.withValues(alpha: 0.66),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: actions),
        ],
      ),
    );
  }
}
