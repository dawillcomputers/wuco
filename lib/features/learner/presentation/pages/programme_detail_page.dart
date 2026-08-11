import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_dimensions.dart';
import '../../application/learner_providers.dart';
import '../../domain/learner_course.dart';
import '../../domain/learner_enums.dart';
import '../../domain/learner_programme.dart';
import '../shell/learner_shell.dart';
import '../widgets/learner_cards.dart';
import '../widgets/learner_detail_widgets.dart';
import '../widgets/learner_lists.dart';
import '../widgets/learner_page_header.dart';
import '../widgets/learner_progress.dart';
import '../widgets/learner_states.dart';
import '../widgets/programme_course_row.dart';

/// A single programme: what it covers, how far the learner has come, and what
/// remains before the certificate.
class ProgrammeDetailPage extends ConsumerWidget {
  const ProgrammeDetailPage({super.key, required this.programmeId});

  final String programmeId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final programme = ref.watch(programmeDetailProvider(programmeId));

    return LearnerPageBody(
      child: LearnerAsync(
        value: programme,
        onRetry: () => ref.invalidate(programmeDetailProvider(programmeId)),
        loading: const LearnerCardSkeleton(count: 2, height: 220),
        data: (found) => found == null
            ? LearnerEmptyState(
                icon: Icons.search_off_outlined,
                title: 'Programme not found',
                message:
                    'This programme is not part of your enrolment, or the link '
                    'is no longer valid.',
                actionLabel: 'BACK TO MY PROGRAMMES',
                onAction: () => context.go('/learner/programmes'),
              )
            : _ProgrammeDetail(programme: found),
      ),
    );
  }
}

class _ProgrammeDetail extends ConsumerWidget {
  const _ProgrammeDetail({required this.programme});

  final LearnerProgramme programme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final courses = ref.watch(programmeCoursesProvider(programme.id));
    final wide = MediaQuery.sizeOf(context).width >= 1000;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LearnerPageHeader(
          eyebrow: programme.category,
          title: programme.title,
          description: programme.summary,
          backRoute: '/learner/programmes',
          backLabel: 'My programmes',
          trailing: LearnerStatusChip.programme(programme.status),
        ),
        LearnerCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              LearnerCourseImage(
                url: programme.imageUrl,
                aspectRatio: wide ? 21 / 6 : 16 / 8,
              ),
              Padding(
                padding: const EdgeInsets.all(WEAInsets.lg),
                child: LearnerFactGrid(
                  facts: [
                    LearnerFact(
                      label: 'Duration',
                      value: programme.durationLabel,
                      icon: Icons.schedule,
                    ),
                    LearnerFact(
                      label: 'Delivery',
                      value: programme.deliveryMode,
                      icon: Icons.public_outlined,
                    ),
                    LearnerFact(
                      label: 'Started',
                      value: programme.startDate == null
                          ? 'Not started'
                          : formatShortDate(programme.startDate!),
                      icon: Icons.event_outlined,
                    ),
                    LearnerFact(
                      label: 'Expected completion',
                      value: programme.expectedCompletion == null
                          ? 'To be confirmed'
                          : formatShortDate(programme.expectedCompletion!),
                      icon: Icons.flag_outlined,
                    ),
                    LearnerFact(
                      label: 'CPD points',
                      value: '${programme.cpdPoints}',
                      icon: Icons.trending_up_outlined,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: WEAInsets.lg),
        LearnerAsync(
          value: courses,
          onRetry: () => ref.invalidate(programmeCoursesProvider(programme.id)),
          loading: const LearnerCardSkeleton(count: 2),
          data: (list) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ProgressPanel(courses: list),
              const SizedBox(height: WEAInsets.lg),
              LearnerPanel(
                title: 'Courses in this programme',
                padding: const EdgeInsets.fromLTRB(
                  WEAInsets.lg,
                  WEAInsets.lg,
                  WEAInsets.lg,
                  WEAInsets.xs,
                ),
                child: list.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.only(bottom: WEAInsets.md),
                        child: Text('No courses have been released yet.'),
                      )
                    : Column(
                        children: [
                          for (var i = 0; i < list.length; i++)
                            ProgrammeCourseRow(
                              course: list[i],
                              last: i == list.length - 1,
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: WEAInsets.lg),
              _ProgrammeSidePanels(programme: programme, courses: list),
            ],
          ),
        ),
      ],
    );
  }
}

class _ProgressPanel extends StatelessWidget {
  const _ProgressPanel({required this.courses});

  final List<LearnerCourse> courses;

  @override
  Widget build(BuildContext context) => LearnerPanel(
    title: 'Overall progress',
    child: LearnerProgressSummary(
      percent: courses.combinedProgressPercent,
      completedLessons: courses.totalCompletedLessons,
      totalLessons: courses.totalLessons,
      remainingMinutes: courses.totalRemainingMinutes,
    ),
  );
}

/// Faculty, certificate standing and CPD, laid out side by side on desktop.
class _ProgrammeSidePanels extends ConsumerWidget {
  const _ProgrammeSidePanels({required this.programme, required this.courses});

  final LearnerProgramme programme;
  final List<LearnerCourse> courses;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final assessments = ref.watch(assessmentsProvider).value ?? const [];
    final courseIds = {for (final course in courses) course.id};
    final related = [
      for (final assessment in assessments)
        if (courseIds.contains(assessment.courseId)) assessment,
    ];

    final faculty = LearnerPanel(
      title: 'Faculty',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (programme.faculty.isEmpty)
            Text(
              'Faculty for this programme will be confirmed shortly.',
              style: theme.textTheme.bodyMedium,
            ),
          for (final member in programme.faculty)
            Padding(
              padding: const EdgeInsets.only(bottom: WEAInsets.xs),
              child: Row(
                children: [
                  const Icon(Icons.person_outline, size: 17),
                  const SizedBox(width: WEAInsets.xs),
                  Expanded(
                    child: Text(member, style: theme.textTheme.bodyLarge),
                  ),
                ],
              ),
            ),
        ],
      ),
    );

    final assessmentPanel = LearnerPanel(
      title: 'Assessments',
      action: TextButton(
        onPressed: () => context.go('/learner/assessments'),
        child: const Text('VIEW ALL'),
      ),
      child: related.isEmpty
          ? Text(
              'No assessments have been scheduled for this programme yet.',
              style: theme.textTheme.bodyMedium,
            )
          : Column(
              children: [
                for (final assessment in related.take(3))
                  Padding(
                    padding: const EdgeInsets.only(bottom: WEAInsets.sm),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                assessment.title,
                                style: theme.textTheme.bodyLarge,
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                assessment.type.label,
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        LearnerStatusChip.assessment(assessment.status),
                      ],
                    ),
                  ),
              ],
            ),
    );

    final certificate = LearnerPanel(
      title: 'Certificate & CPD',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                programme.hasCertificate
                    ? Icons.verified_outlined
                    : Icons.hourglass_empty,
                size: 18,
              ),
              const SizedBox(width: WEAInsets.xs),
              Expanded(
                child: Text(
                  programme.status == ProgrammeStatus.certificateAvailable ||
                          programme.hasCertificate
                      ? 'Your certificate is available.'
                      : 'Your certificate is issued once the programme '
                            'assessments are complete.',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: WEAInsets.sm),
          Text(
            '${programme.cpdPoints} CPD points on completion',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: WEAInsets.md),
          const LearnerLockedNote(
            message:
                'Progress, results and certificate status are set by WEA and '
                'cannot be edited here.',
          ),
          if (programme.hasCertificate) ...[
            const SizedBox(height: WEAInsets.md),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton(
                onPressed: () => context.go(
                  '/learner/certificates/${programme.certificateId}',
                ),
                child: const Text('VIEW CERTIFICATE'),
              ),
            ),
          ],
        ],
      ),
    );

    return LearnerResponsiveGrid(
      minItemWidth: 320,
      children: [faculty, assessmentPanel, certificate],
    );
  }
}
