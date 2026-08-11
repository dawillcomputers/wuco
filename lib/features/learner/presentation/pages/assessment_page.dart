import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_dimensions.dart';
import '../../application/learner_providers.dart';
import '../../domain/learner_enums.dart';
import '../../domain/learner_records.dart';
import '../shell/learner_shell.dart';
import '../widgets/assessment_cards.dart';
import '../widgets/learner_page_header.dart';
import '../widgets/learner_states.dart';

/// Everything the learner is expected to sit, grouped by what needs attention.
class AssessmentPage extends ConsumerWidget {
  const AssessmentPage({super.key});

  /// Grouped so the learner sees what is open before what is historic.
  static List<(String, List<Assessment>)> group(List<Assessment> all) {
    List<Assessment> matching(Set<AssessmentStatus> statuses) => [
      for (final assessment in all)
        if (statuses.contains(assessment.status)) assessment,
    ]..sort((a, b) {
      final left = a.dueDate;
      final right = b.dueDate;
      if (left == null || right == null) return 0;
      return left.compareTo(right);
    });

    return [
      ('Available now', matching({AssessmentStatus.available})),
      ('Upcoming', matching({AssessmentStatus.upcoming})),
      (
        'Awaiting result',
        matching({AssessmentStatus.submitted, AssessmentStatus.marking}),
      ),
      (
        'Completed',
        matching({AssessmentStatus.completed, AssessmentStatus.missed}),
      ),
    ];
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => LearnerPageBody(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LearnerPageHeader(
          eyebrow: 'Assessments',
          title: 'Your assessments',
          description:
              'Quizzes, examinations, case studies and capstone submissions '
              'across your programmes.',
          trailing: OutlinedButton(
            onPressed: () => context.go('/learner/results'),
            child: const Text('VIEW RESULTS'),
          ),
        ),
        LearnerAsync(
          value: ref.watch(assessmentsProvider),
          onRetry: () => ref.invalidate(assessmentsProvider),
          loading: const LearnerCardSkeleton(count: 3, height: 170),
          data: (all) => all.isEmpty
              ? const LearnerEmptyState(
                  icon: Icons.assignment_outlined,
                  title: 'No assessments yet',
                  message:
                      'Assessments appear here as your courses reach them. '
                      'You will be notified when one opens.',
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final (title, items) in group(all))
                      if (items.isNotEmpty) ...[
                        LearnerSectionHeading(title: title),
                        LearnerResponsiveGrid(
                          minItemWidth: 330,
                          children: [
                            for (final assessment in items)
                              AssessmentCard(assessment: assessment),
                          ],
                        ),
                        const SizedBox(height: WEAInsets.xl),
                      ],
                  ],
                ),
        ),
      ],
    ),
  );
}
