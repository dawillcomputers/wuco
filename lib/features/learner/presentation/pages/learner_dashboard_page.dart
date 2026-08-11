import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_dimensions.dart';
import '../../../../shared/animations/wea_animations.dart';
import '../../../authentication/application/auth_controller.dart';
import '../../application/learner_providers.dart';
import '../shell/learner_shell.dart';
import '../widgets/dashboard_sections.dart';
import '../widgets/learner_cards.dart';
import '../widgets/learner_lists.dart';
import '../widgets/learner_states.dart';

/// The learner's home screen.
///
/// Composition only: every block is its own widget and every figure comes from
/// a provider, so this file stays readable as the dashboard grows.
class LearnerDashboardPage extends ConsumerWidget {
  const LearnerDashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final account = ref.watch(currentProfileProvider);
    final wide = MediaQuery.sizeOf(context).width >= 1080;

    return LearnerPageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          WEAEntrance(
            child: _WelcomeSection(firstName: account?.firstName ?? ''),
          ),
          const SizedBox(height: WEAInsets.lg),
          WEAEntrance(
            delay: const Duration(milliseconds: 60),
            child: const _StatsSection(),
          ),
          const SizedBox(height: WEAInsets.xl),

          // Priority order on mobile is welcome → continue → progress →
          // upcoming → programmes → activity, so the single column simply
          // follows the source order below.
          if (wide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 7,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _ContinueLearningSection(),
                      const SizedBox(height: WEAInsets.xl),
                      const _ProgrammesSection(),
                    ],
                  ),
                ),
                const SizedBox(width: WEAInsets.lg),
                Expanded(
                  flex: 4,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _UpcomingSection(),
                      const SizedBox(height: WEAInsets.xl),
                      const _ActivitySection(),
                    ],
                  ),
                ),
              ],
            )
          else ...[
            const _ContinueLearningSection(),
            const SizedBox(height: WEAInsets.xl),
            const _UpcomingSection(),
            const SizedBox(height: WEAInsets.xl),
            const _ProgrammesSection(),
            const SizedBox(height: WEAInsets.xl),
            const _ActivitySection(),
          ],

          const SizedBox(height: WEAInsets.xl),
          const _FutureModulesSection(),
        ],
      ),
    );
  }
}

class _WelcomeSection extends ConsumerWidget {
  const _WelcomeSection({required this.firstName});

  final String firstName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(learnerStatsProvider);
    final incomplete = ref.watch(profileCompletionProvider).value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LearnerWelcomeBanner(
          firstName: firstName,
          streakDays: stats.value?.streakDays ?? 0,
        ),
        if (incomplete != null && !incomplete.isComplete) ...[
          const SizedBox(height: WEAInsets.sm),
          ProfileCompletionCard(completion: incomplete),
        ],
      ],
    );
  }
}

class _StatsSection extends ConsumerWidget {
  const _StatsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) => LearnerAsync(
    value: ref.watch(learnerStatsProvider),
    onRetry: () => ref.invalidate(learnerStatsProvider),
    loading: const LearnerCardSkeleton(count: 1, height: 90),
    data: (stats) => LearnerStatRow(stats: stats),
  );
}

class _ContinueLearningSection extends ConsumerWidget {
  const _ContinueLearningSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const LearnerSectionHeading(
        title: 'Continue learning',
        subtitle: 'Pick up where you left off.',
      ),
      LearnerAsync(
        value: ref.watch(continueLearningProvider),
        onRetry: () => ref.invalidate(continueLearningProvider),
        loading: const LearnerCardSkeleton(count: 1, height: 220),
        data: (course) => course == null
            ? LearnerEmptyState(
                icon: Icons.menu_book_outlined,
                title: 'No course in progress',
                message:
                    'Once you begin a course it will appear here so you can '
                    'resume in a single tap.',
                actionLabel: 'BROWSE MY COURSES',
                onAction: () => context.go('/learner/courses'),
              )
            : ContinueLearningCard(course: course),
      ),
    ],
  );
}

class _ProgrammesSection extends ConsumerWidget {
  const _ProgrammesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      LearnerSectionHeading(
        title: 'My programmes',
        subtitle: 'The qualifications you are working towards.',
        actionLabel: 'VIEW ALL',
        onAction: () => context.go('/learner/programmes'),
      ),
      LearnerAsync(
        value: ref.watch(enrolledProgrammesProvider),
        onRetry: () => ref.invalidate(enrolledProgrammesProvider),
        loading: const LearnerCardSkeleton(count: 2),
        data: (programmes) => programmes.isEmpty
            ? LearnerEmptyState(
                icon: Icons.workspace_premium_outlined,
                title: 'No active programmes',
                message: 'You haven’t enrolled in a programme yet.',
                actionLabel: 'EXPLORE PROGRAMMES',
                onAction: () => context.go('/programmes'),
              )
            : Column(
                children: [
                  for (final programme in programmes.take(2))
                    Padding(
                      padding: const EdgeInsets.only(bottom: WEAInsets.md),
                      child: LearnerProgrammeCard(programme: programme),
                    ),
                ],
              ),
      ),
    ],
  );
}

class _UpcomingSection extends ConsumerWidget {
  const _UpcomingSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const LearnerSectionHeading(
        title: 'Upcoming',
        subtitle: 'What is scheduled next.',
      ),
      LearnerAsync(
        value: ref.watch(upcomingActivityProvider),
        onRetry: () => ref.invalidate(upcomingActivityProvider),
        loading: const LearnerCardSkeleton(count: 1, height: 180),
        data: (items) => items.isEmpty
            ? const LearnerEmptyState(
                icon: Icons.event_available_outlined,
                title: 'Nothing scheduled',
                message:
                    'Live sessions, assessments and milestones will appear '
                    'here as they are announced.',
              )
            : LearnerCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: WEAInsets.md,
                  vertical: WEAInsets.xs,
                ),
                child: Column(
                  children: [
                    for (final item in items)
                      LearnerUpcomingTile(item: item),
                  ],
                ),
              ),
      ),
    ],
  );
}

class _ActivitySection extends ConsumerWidget {
  const _ActivitySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const LearnerSectionHeading(
        title: 'Recent learning activity',
        subtitle: 'A record of your progress.',
      ),
      LearnerAsync(
        value: ref.watch(recentActivityProvider),
        onRetry: () => ref.invalidate(recentActivityProvider),
        loading: const LearnerCardSkeleton(count: 1, height: 200),
        data: (items) => items.isEmpty
            ? const LearnerEmptyState(
                icon: Icons.timeline_outlined,
                title: 'No activity yet',
                message:
                    'Completed lessons, submitted assessments and awarded CPD '
                    'points will be listed here.',
              )
            : LearnerActivityTimeline(items: items),
      ),
    ],
  );
}

/// Entry points to the AI Mentor (Module 09) and Professional Network
/// (Module 10). Presented here, but neither system is implemented yet.
class _FutureModulesSection extends StatelessWidget {
  const _FutureModulesSection();

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 860;
    const mentor = FeatureEntryCard(
      eyebrow: 'WEA AI Mentor',
      title: 'Your intelligent learning companion.',
      description:
          'Course-aware guidance, lesson explanations and practice questions, '
          'grounded in the material you are studying.',
      actionLabel: 'Ask WEA AI Mentor',
      route: '/learner/ai-mentor',
      icon: Icons.auto_awesome_outlined,
      onDark: true,
    );
    const network = FeatureEntryCard(
      eyebrow: 'WEA Professional Network',
      title: 'Connect with executives, faculty and fellow professionals.',
      description:
          'Verified credentials, executive events and a professional community '
          'built around WEA alumni.',
      actionLabel: 'Explore the network',
      route: '/learner/professional-network',
      icon: Icons.groups_outlined,
    );

    if (narrow) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          mentor,
          SizedBox(height: WEAInsets.md),
          network,
        ],
      );
    }
    return const IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: mentor),
          SizedBox(width: WEAInsets.md),
          Expanded(child: network),
        ],
      ),
    );
  }
}
