import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/animations/wea_animations.dart';
import '../../application/learner_providers.dart';
import '../shell/learner_shell.dart';
import '../widgets/credential_cards.dart';
import '../widgets/learner_page_header.dart';
import '../widgets/learner_states.dart';

/// Certificates the learner has earned, and those still pending issue.
class CertificatePage extends ConsumerWidget {
  const CertificatePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => LearnerPageBody(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LearnerPageHeader(
          eyebrow: 'Certificates',
          title: 'Your certificates',
          description:
              'Formal recognition of the programmes you have completed with '
              'WUCO Executive Academy.',
          trailing: OutlinedButton(
            onPressed: () => context.go('/learner/credentials'),
            child: const Text('DIGITAL CREDENTIALS'),
          ),
        ),
        LearnerAsync(
          value: ref.watch(certificatesProvider),
          onRetry: () => ref.invalidate(certificatesProvider),
          loading: const LearnerCardSkeleton(count: 2, height: 240),
          data: (certificates) => certificates.isEmpty
              ? LearnerEmptyState(
                  icon: Icons.workspace_premium_outlined,
                  title: 'No certificates yet',
                  message:
                      'Complete a programme and its assessments, and your '
                      'certificate will be issued here.',
                  actionLabel: 'VIEW MY PROGRAMMES',
                  onAction: () => context.go('/learner/programmes'),
                )
              : LearnerResponsiveGrid(
                  minItemWidth: 340,
                  children: [
                    for (var i = 0; i < certificates.length; i++)
                      WEAEntrance(
                        delay: Duration(milliseconds: 60 * i),
                        child: CertificateCard(certificate: certificates[i]),
                      ),
                  ],
                ),
        ),
      ],
    ),
  );
}
