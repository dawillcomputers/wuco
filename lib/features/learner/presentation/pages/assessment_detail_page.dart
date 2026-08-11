import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../application/learner_providers.dart';
import '../../domain/learner_enums.dart';
import '../../domain/learner_records.dart';
import '../shell/learner_shell.dart';
import '../widgets/learner_detail_widgets.dart';
import '../widgets/learner_lists.dart';
import '../widgets/learner_page_header.dart';
import '../widgets/learner_progress.dart';
import '../widgets/learner_states.dart';

/// One assessment in full: what it is, when it closes, and what happens next.
class AssessmentDetailPage extends ConsumerWidget {
  const AssessmentDetailPage({super.key, required this.assessmentId});

  final String assessmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assessments = ref.watch(assessmentsProvider);

    return LearnerPageBody(
      child: LearnerAsync(
        value: assessments,
        onRetry: () => ref.invalidate(assessmentsProvider),
        loading: const LearnerCardSkeleton(count: 2, height: 200),
        data: (all) {
          final assessment = all
              .where((item) => item.id == assessmentId)
              .firstOrNull;
          if (assessment == null) {
            return LearnerEmptyState(
              icon: Icons.search_off_outlined,
              title: 'Assessment not found',
              message:
                  'This assessment is not part of your enrolment, or the link '
                  'is no longer valid.',
              actionLabel: 'BACK TO ASSESSMENTS',
              onAction: () => context.go('/learner/assessments'),
            );
          }
          return _AssessmentDetail(assessment: assessment);
        },
      ),
    );
  }
}

class _AssessmentDetail extends ConsumerWidget {
  const _AssessmentDetail({required this.assessment});

  final Assessment assessment;

  bool get _isOpen =>
      assessment.status == AssessmentStatus.available &&
      assessment.attemptsRemaining > 0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final result = ref
        .watch(resultsProvider)
        .value
        ?.where((item) => item.assessmentId == assessment.id)
        .firstOrNull;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LearnerPageHeader(
          eyebrow: assessment.type.label,
          title: assessment.title,
          description:
              '${assessment.courseTitle} · ${assessment.programmeTitle}',
          backRoute: '/learner/assessments',
          backLabel: 'Assessments',
          trailing: LearnerStatusChip.assessment(assessment.status),
        ),
        LearnerPanel(
          title: 'Details',
          child: LearnerFactGrid(
            facts: [
              LearnerFact(
                label: 'Type',
                value: assessment.type.label,
                icon: Icons.category_outlined,
              ),
              LearnerFact(
                label: 'Duration',
                value: '${assessment.durationMinutes} minutes',
                icon: Icons.timer_outlined,
              ),
              LearnerFact(
                label: 'Closes',
                value: assessment.dueDate == null
                    ? 'No deadline set'
                    : formatShortDate(assessment.dueDate!),
                icon: Icons.event_outlined,
              ),
              LearnerFact(
                label: 'Attempts',
                value:
                    '${assessment.attemptsRemaining} of '
                    '${assessment.attemptsAllowed} remaining',
                icon: Icons.replay_outlined,
              ),
            ],
          ),
        ),
        const SizedBox(height: WEAInsets.lg),
        LearnerPanel(
          title: 'Before you begin',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const LearnerBulletList(
                items: [
                  'Set aside uninterrupted time — the assessment is timed once '
                      'it starts.',
                  'Your submission is marked by WEA faculty and released to '
                      'your results.',
                  'Only your own work may be submitted.',
                ],
              ),
              const SizedBox(height: WEAInsets.md),
              // Wraps so the note drops beneath the button on a phone rather
              // than competing with it for the same line.
              Wrap(
                spacing: WEAInsets.sm,
                runSpacing: WEAInsets.xs,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    height: 46,
                    child: ElevatedButton(
                      // Sitting an assessment belongs to the assessment engine
                      // in a later module; the entry point is prepared here.
                      onPressed: _isOpen ? () => _notYetAvailable(context) : null,
                      child: Text(
                        _isOpen ? 'BEGIN ASSESSMENT' : 'NOT CURRENTLY OPEN',
                      ),
                    ),
                  ),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 360),
                    child: Text(
                      _isOpen
                          ? 'You may begin at any point before the closing '
                                'date.'
                          : 'This assessment is ${assessment.status.label
                                .toLowerCase()}.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: WEAInsets.lg),
        LearnerPanel(
          title: 'Result',
          child: result == null
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'No result has been published for this assessment yet.',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: WEAInsets.sm),
                    const LearnerLockedNote(
                      message:
                          'Scores and grades are set by WEA faculty and cannot '
                          'be changed from your account.',
                    ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          '${result.percentageRounded}%  ·  ${result.grade}',
                          style: theme.textTheme.headlineSmall,
                        ),
                        const Spacer(),
                        LearnerStatusChip.outcome(result.outcome),
                      ],
                    ),
                    const SizedBox(height: WEAInsets.sm),
                    OutlinedButton(
                      onPressed: () =>
                          context.go('/learner/results/${result.id}'),
                      child: const Text('VIEW FULL RESULT'),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

void _notYetAvailable(BuildContext context) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      backgroundColor: WEAColors.navy,
      content: Text(
        'The assessment engine opens with the next release. Your deadline and '
        'attempts are already recorded.',
      ),
    ),
  );
}
