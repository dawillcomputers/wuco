import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../application/learner_providers.dart';
import '../shell/learner_shell.dart';
import '../widgets/credential_cards.dart';
import '../widgets/learner_detail_widgets.dart';
import '../widgets/learner_page_header.dart';
import '../widgets/learner_states.dart';

/// Verifiable digital credentials earned through WEA.
class CredentialPage extends ConsumerWidget {
  const CredentialPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => LearnerPageBody(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LearnerPageHeader(
          eyebrow: 'Digital credentials',
          title: 'Your verifiable credentials',
          description:
              'Portable, verifiable evidence of what you have achieved — for '
              'your professional profile, employer or regulator.',
          trailing: OutlinedButton(
            onPressed: () => context.go('/learner/certificates'),
            child: const Text('CERTIFICATES'),
          ),
        ),
        LearnerAsync(
          value: ref.watch(credentialsProvider),
          onRetry: () => ref.invalidate(credentialsProvider),
          loading: const LearnerCardSkeleton(count: 2, height: 180),
          data: (credentials) => credentials.isEmpty
              ? LearnerEmptyState(
                  icon: Icons.badge_outlined,
                  title: 'No credentials yet',
                  message:
                      'Digital credentials are issued alongside your first '
                      'certificate.',
                  actionLabel: 'VIEW MY PROGRAMMES',
                  onAction: () => context.go('/learner/programmes'),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LearnerResponsiveGrid(
                      minItemWidth: 380,
                      children: [
                        for (final credential in credentials)
                          CredentialCard(
                            credential: credential,
                            onShare: () => _sharePending(context),
                          ),
                      ],
                    ),
                    const SizedBox(height: WEAInsets.lg),
                    const LearnerLockedNote(
                      message:
                          'Credential identifiers, issue dates and validity '
                          'are controlled by WEA. You choose only whether to '
                          'share them.',
                    ),
                  ],
                ),
        ),
      ],
    ),
  );
}

void _sharePending(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      backgroundColor: WEAColors.navy,
      content: Text(
        'Credential sharing arrives with the Professional Network. Your '
        'credential is already issued and verifiable.',
      ),
    ),
  );
}
