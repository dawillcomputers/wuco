import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../application/learner_providers.dart';
import '../shell/learner_shell.dart';
import '../widgets/learner_cards.dart';
import '../widgets/learner_detail_widgets.dart';
import '../widgets/learner_page_header.dart';
import '../widgets/learner_states.dart';

/// Entry point for the WEA Professional Network.
///
/// The network itself is Module 10 — no connections, messaging, feeds or groups
/// are implemented here. This page explains what is coming and shows what the
/// learner already holds that will carry into it.
class ProfessionalNetworkPage extends ConsumerWidget {
  const ProfessionalNetworkPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final credentials = ref.watch(credentialsProvider).value ?? const [];

    return LearnerPageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const LearnerPageHeader(
            eyebrow: 'WEA Professional Network',
            title:
                'Connect with executives, faculty and fellow WEA professionals.',
            description:
                'A professional ecosystem for WEA graduates: verified records, '
                'executive events and a community of leaders across Africa and '
                'beyond.',
          ),
          LearnerCard(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const LearnerCourseImage(
                  url:
                      'https://images.unsplash.com/photo-1511578314322-379afb476865'
                      '?auto=format&fit=crop&w=1400&q=82',
                  aspectRatio: 21 / 7,
                ),
                Padding(
                  padding: const EdgeInsets.all(WEAInsets.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'LEARN → CERTIFY → CONNECT → DEVELOP → LEAD',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: WEAColors.accent,
                          letterSpacing: 1.8,
                        ),
                      ),
                      const SizedBox(height: WEAInsets.sm),
                      Text(
                        'Your WEA record becomes your professional standing.',
                        style: theme.textTheme.headlineSmall,
                      ),
                      const SizedBox(height: WEAInsets.xs),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 620),
                        child: Text(
                          'The network opens with member profiles built from '
                          'the certificates, credentials and CPD you have '
                          'already earned. Nothing is shared until you choose '
                          'to share it.',
                          style: theme.textTheme.bodyLarge,
                        ),
                      ),
                      const SizedBox(height: WEAInsets.lg),
                      Wrap(
                        spacing: WEAInsets.sm,
                        runSpacing: WEAInsets.xs,
                        children: [
                          OutlinedButton(
                            onPressed: () => context.go('/learner/profile'),
                            child: const Text('PREPARE MY PROFILE'),
                          ),
                          TextButton(
                            onPressed: () =>
                                context.go('/learner/credentials'),
                            child: const Text('MY CREDENTIALS'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: WEAInsets.lg),
          LearnerResponsiveGrid(
            minItemWidth: 320,
            children: [
              const LearnerPanel(
                title: 'What the network will offer',
                child: LearnerBulletList(
                  items: [
                    'Professional profiles built on verified WEA records',
                    'Digital badges and certificate verification',
                    'Executive events and faculty briefings',
                    'Research and practice notes from across the academy',
                    'Introductions by sector, region and expertise',
                  ],
                ),
              ),
              LearnerPanel(
                title: 'What you already hold',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      credentials.isEmpty
                          ? 'Your first verified credential will be issued '
                                'alongside your first certificate, and will '
                                'carry into the network automatically.'
                          : 'You hold ${credentials.length} verified '
                                '${credentials.length == 1 ? 'credential' : 'credentials'} '
                                'that will carry into your member profile.',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: WEAInsets.md),
                    const LearnerLockedNote(
                      message:
                          'You control your visibility. Nothing from your WEA '
                          'record is published without your consent.',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
