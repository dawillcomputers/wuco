import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_dimensions.dart';
import '../../application/learner_providers.dart';
import '../../domain/learner_course.dart';
import '../shell/learner_shell.dart';
import '../widgets/curriculum_widget.dart';
import '../widgets/learner_cards.dart';
import '../widgets/learner_detail_widgets.dart';
import '../widgets/learner_page_header.dart';
import '../widgets/learner_progress.dart';
import '../widgets/learner_states.dart';

/// A course overview: what it teaches, how far the learner has come, and the
/// full curriculum before entering the learning interface.
class CourseDetailPage extends ConsumerWidget {
  const CourseDetailPage({super.key, required this.courseId});

  final String courseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => LearnerPageBody(
    child: LearnerAsync(
      value: ref.watch(courseDetailProvider(courseId)),
      onRetry: () => ref.invalidate(courseDetailProvider(courseId)),
      loading: const LearnerCardSkeleton(count: 2, height: 220),
      data: (course) => course == null
          ? LearnerEmptyState(
              icon: Icons.search_off_outlined,
              title: 'Course not found',
              message:
                  'This course is not part of your enrolment, or the link is '
                  'no longer valid.',
              actionLabel: 'BACK TO MY COURSES',
              onAction: () => context.go('/learner/courses'),
            )
          : _CourseDetail(course: course),
    ),
  );
}

class _CourseDetail extends ConsumerWidget {
  const _CourseDetail({required this.course});

  final LearnerCourse course;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    final programme = ref
        .watch(programmeDetailProvider(course.programmeId))
        .value;

    final overview = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LearnerCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              LearnerCourseImage(
                url: course.imageUrl,
                aspectRatio: wide ? 21 / 7 : 16 / 8,
              ),
              Padding(
                padding: const EdgeInsets.all(WEAInsets.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(course.summary, style: theme.textTheme.bodyLarge),
                    const SizedBox(height: WEAInsets.lg),
                    LearnerFactGrid(
                      facts: [
                        LearnerFact(
                          label: 'Faculty',
                          value: course.faculty,
                          icon: Icons.person_outline,
                        ),
                        LearnerFact(
                          label: 'Programme',
                          value: programme?.title ?? 'WEA programme',
                          icon: Icons.workspace_premium_outlined,
                        ),
                        LearnerFact(
                          label: 'Duration',
                          value: course.durationLabel,
                          icon: Icons.schedule,
                        ),
                        LearnerFact(
                          label: 'CPD points',
                          value: '${course.cpdPoints}',
                          icon: Icons.trending_up_outlined,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (course.objectives.isNotEmpty) ...[
          const SizedBox(height: WEAInsets.lg),
          LearnerPanel(
            title: 'What you will be able to do',
            child: LearnerBulletList(items: course.objectives),
          ),
        ],
        const SizedBox(height: WEAInsets.lg),
        LearnerPanel(
          title: 'Curriculum',
          padding: const EdgeInsets.fromLTRB(0, WEAInsets.lg, 0, WEAInsets.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CurriculumWidget(
                course: course,
                onSelectLesson: (lesson) => context.go(
                  '/learner/courses/${course.id}/lessons/${lesson.id}',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: WEAInsets.lg),
        _ResourcesPanel(course: course),
      ],
    );

    final aside = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LearnerPanel(
          title: 'Your progress',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              LearnerProgressSummary(
                percent: course.progressPercent,
                completedLessons: course.completedLessons,
                totalLessons: course.totalLessons,
                remainingMinutes: course.remainingMinutes,
              ),
              const SizedBox(height: WEAInsets.md),
              SizedBox(
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: () =>
                      context.go('/learner/courses/${course.id}/learn'),
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: Text(
                    course.completedLessons == 0
                        ? 'START COURSE'
                        : 'CONTINUE COURSE',
                  ),
                ),
              ),
              if (course.currentLesson != null) ...[
                const SizedBox(height: WEAInsets.sm),
                Text(
                  'Up next: ${course.currentLesson!.title}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: WEAInsets.lg),
        LearnerPanel(
          title: 'Assessment & certificate',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This course contributes towards the '
                '${programme?.title ?? 'programme'} certificate and carries '
                '${course.cpdPoints} CPD points on completion.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: WEAInsets.sm),
              Wrap(
                spacing: WEAInsets.sm,
                runSpacing: WEAInsets.xs,
                children: [
                  OutlinedButton(
                    onPressed: () => context.go('/learner/assessments'),
                    child: const Text('ASSESSMENTS'),
                  ),
                  TextButton(
                    onPressed: () => context.go('/learner/results'),
                    child: const Text('MY RESULTS'),
                  ),
                ],
              ),
              const SizedBox(height: WEAInsets.sm),
              const LearnerLockedNote(
                message:
                    'Completion, grades and certificate eligibility are '
                    'determined by WEA.',
              ),
            ],
          ),
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LearnerPageHeader(
          eyebrow: course.category,
          title: course.title,
          backRoute: '/learner/courses',
          backLabel: 'My courses',
          trailing: LearnerStatusChip.course(course.status),
        ),
        if (wide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 7, child: overview),
              const SizedBox(width: WEAInsets.lg),
              Expanded(flex: 4, child: aside),
            ],
          )
        else ...[
          aside,
          const SizedBox(height: WEAInsets.lg),
          overview,
        ],
      ],
    );
  }
}

/// Resources gathered from across the course's lessons.
class _ResourcesPanel extends StatelessWidget {
  const _ResourcesPanel({required this.course});

  final LearnerCourse course;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // De-duplicated by title: the same slide deck often appears on several
    // lessons and should be listed once at course level.
    final seen = <String>{};
    final resources = [
      for (final lesson in course.lessons)
        for (final resource in lesson.resources)
          if (seen.add(resource.title)) resource,
    ];

    return LearnerPanel(
      title: 'Course resources',
      child: resources.isEmpty
          ? Text(
              'Resources will be published alongside the lessons.',
              style: theme.textTheme.bodyMedium,
            )
          : Column(
              children: [
                for (final resource in resources)
                  Padding(
                    padding: const EdgeInsets.only(bottom: WEAInsets.xs),
                    child: Row(
                      children: [
                        const Icon(Icons.description_outlined, size: 17),
                        const SizedBox(width: WEAInsets.xs),
                        Expanded(
                          child: Text(
                            resource.title,
                            style: theme.textTheme.bodyLarge,
                          ),
                        ),
                        Text(resource.kind, style: theme.textTheme.bodySmall),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}
