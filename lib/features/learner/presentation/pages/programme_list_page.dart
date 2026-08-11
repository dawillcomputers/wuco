import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/animations/wea_animations.dart';
import '../../application/learner_providers.dart';
import '../shell/learner_shell.dart';
import '../widgets/learner_cards.dart';
import '../widgets/learner_page_header.dart';
import '../widgets/learner_states.dart';

/// Every programme the learner is enrolled on.
class ProgrammeListPage extends ConsumerWidget {
  const ProgrammeListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final programmes = ref.watch(enrolledProgrammesProvider);

    return LearnerPageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const LearnerPageHeader(
            eyebrow: 'My programmes',
            title: 'Your executive programmes',
            description:
                'The qualifications you are enrolled on, with progress and '
                'certificate status for each.',
          ),
          LearnerAsync(
            value: programmes,
            onRetry: () => ref.invalidate(enrolledProgrammesProvider),
            loading: const LearnerCardSkeleton(count: 3, height: 200),
            data: (items) => items.isEmpty
                ? LearnerEmptyState(
                    icon: Icons.workspace_premium_outlined,
                    title: 'No active programmes',
                    message: 'You haven’t enrolled in a programme yet.',
                    actionLabel: 'EXPLORE PROGRAMMES',
                    onAction: () => context.go('/programmes'),
                  )
                : LearnerResponsiveGrid(
                    minItemWidth: 340,
                    children: [
                      for (var i = 0; i < items.length; i++)
                        WEAEntrance(
                          delay: Duration(milliseconds: 60 * i),
                          child: LearnerProgrammeCard(programme: items[i]),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
