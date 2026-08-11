import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../authentication/application/auth_controller.dart';
import '../shell/learner_shell.dart';
import '../widgets/learner_detail_widgets.dart';
import '../widgets/learner_page_header.dart';

/// Entry point for the WEA AI Mentor.
///
/// The mentor itself is Module 09. This page exists so the destination is real
/// and self-explanatory rather than a dead navigation item — no AI behaviour is
/// implemented here.
class AiMentorPage extends ConsumerWidget {
  const AiMentorPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final firstName = ref.watch(currentProfileProvider)?.firstName.trim() ?? '';

    return LearnerPageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const LearnerPageHeader(
            eyebrow: 'WEA AI Mentor',
            title: 'Your intelligent learning companion.',
            description:
                'A mentor that knows the material you are studying — ready to '
                'explain, summarise and test your understanding.',
          ),
          Container(
            padding: const EdgeInsets.all(WEAInsets.xl),
            decoration: BoxDecoration(
              color: WEAColors.navy,
              borderRadius: BorderRadius.circular(WEAInsets.radius),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.auto_awesome_outlined,
                      color: WEAColors.accentSoft,
                      size: 22,
                    ),
                    const SizedBox(width: WEAInsets.xs),
                    Text(
                      'ARRIVING SOON',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: WEAColors.accentSoft,
                        letterSpacing: 1.8,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: WEAInsets.md),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: Text(
                    firstName.isEmpty
                        ? 'The WEA AI Mentor is being prepared for your '
                              'programmes.'
                        : '$firstName, the WEA AI Mentor is being prepared for '
                              'your programmes.',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: WEAColors.offWhite,
                    ),
                  ),
                ),
                const SizedBox(height: WEAInsets.sm),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: Text(
                    'It will draw only on the courses you are enrolled on, so '
                    'its answers stay grounded in WEA material rather than '
                    'general web content.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: WEAColors.offWhite.withValues(alpha: .82),
                    ),
                  ),
                ),
                const SizedBox(height: WEAInsets.lg),
                Wrap(
                  spacing: WEAInsets.sm,
                  runSpacing: WEAInsets.xs,
                  children: [
                    ElevatedButton(
                      onPressed: () => context.go('/learner/courses'),
                      child: const Text('CONTINUE LEARNING'),
                    ),
                    TextButton(
                      onPressed: () => context.go('/learner/settings'),
                      child: Text(
                        'Manage notifications',
                        style: TextStyle(color: WEAColors.accentSoft),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: WEAInsets.lg),
          LearnerPanel(
            title: 'What the AI Mentor will do',
            child: const LearnerBulletList(
              items: [
                'Answer questions about the courses you are enrolled on',
                'Explain a lesson again, in a different way',
                'Summarise a module before an assessment',
                'Generate practice questions from your own material',
                'Suggest what to study next, based on your progress',
                'Point towards career pathways across WEA programmes',
              ],
            ),
          ),
          const SizedBox(height: WEAInsets.lg),
          const LearnerLockedNote(
            message:
                'The AI Mentor will never have access to another learner’s '
                'records, and it does not set your grades or progress.',
          ),
        ],
      ),
    );
  }
}
