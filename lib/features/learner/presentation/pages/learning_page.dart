import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../application/learner_providers.dart';
import '../../domain/learner_course.dart';
import '../widgets/curriculum_widget.dart';
import '../widgets/learner_progress.dart';
import '../widgets/learner_states.dart';
import 'lesson_page.dart';

/// The learning interface: curriculum on the left, lesson content on the right.
///
/// Deliberately outside the dashboard shell. Learning is a focused mode, and a
/// third navigation column would crowd the curriculum off the screen.
class LearningPage extends ConsumerStatefulWidget {
  const LearningPage({super.key, required this.courseId, this.lessonId});

  final String courseId;

  /// Null on `/learn`, which resumes at the course's current lesson.
  final String? lessonId;

  /// At or above this the curriculum is a persistent panel; below it, a drawer.
  static const curriculumBreakpoint = 1024.0;

  @override
  ConsumerState<LearningPage> createState() => _LearningPageState();
}

class _LearningPageState extends ConsumerState<LearningPage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    // Opening the course is what makes it the most recent one; recorded once
    // per entry rather than on every rebuild.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(learnerActionsProvider).recordAccess(widget.courseId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final course = ref.watch(courseDetailProvider(widget.courseId));
    final wide =
        MediaQuery.sizeOf(context).width >= LearningPage.curriculumBreakpoint;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: WEAColors.background,
      drawer: wide
          ? null
          : Drawer(
              backgroundColor: WEAColors.background,
              width: 320,
              child: SafeArea(
                child: course.value == null
                    ? const SizedBox.shrink()
                    : _CurriculumPanel(
                        course: course.value!,
                        activeLessonId: _resolveLesson(course.value!)?.id,
                        onSelect: (lesson) {
                          Navigator.of(context).pop();
                          _open(lesson);
                        },
                      ),
              ),
            ),
      body: SafeArea(
        child: LearnerAsync(
          value: course,
          onRetry: () =>
              ref.invalidate(courseDetailProvider(widget.courseId)),
          loading: const Center(child: CircularProgressIndicator()),
          data: (found) => found == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(WEAInsets.lg),
                    child: LearnerEmptyState(
                      icon: Icons.search_off_outlined,
                      title: 'Course not available',
                      message:
                          'This course is not part of your enrolment, or the '
                          'link is no longer valid.',
                      actionLabel: 'BACK TO MY COURSES',
                      onAction: () => context.go('/learner/courses'),
                    ),
                  ),
                )
              : _LearningLayout(
                  course: found,
                  lesson: _resolveLesson(found),
                  wide: wide,
                  onOpenCurriculum: () => _scaffoldKey.currentState?.openDrawer(),
                  onSelect: _open,
                ),
        ),
      ),
    );
  }

  /// The lesson named in the route, or the one the learner should resume on.
  Lesson? _resolveLesson(LearnerCourse course) {
    final id = widget.lessonId;
    if (id == null) return course.currentLesson;
    for (final lesson in course.lessons) {
      if (lesson.id == id) return lesson;
    }
    return course.currentLesson;
  }

  void _open(Lesson lesson) =>
      context.go('/learner/courses/${widget.courseId}/lessons/${lesson.id}');
}

class _LearningLayout extends StatelessWidget {
  const _LearningLayout({
    required this.course,
    required this.lesson,
    required this.wide,
    required this.onOpenCurriculum,
    required this.onSelect,
  });

  final LearnerCourse course;
  final Lesson? lesson;
  final bool wide;
  final VoidCallback onOpenCurriculum;
  final ValueChanged<Lesson> onSelect;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _LearningTopBar(
        course: course,
        showCurriculumButton: !wide,
        onOpenCurriculum: onOpenCurriculum,
      ),
      Expanded(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (wide)
              SizedBox(
                width: 340,
                child: DecoratedBox(
                  decoration: const BoxDecoration(
                    color: WEAColors.secondaryBackground,
                    border: Border(
                      right: BorderSide(color: WEAColors.border),
                    ),
                  ),
                  child: _CurriculumPanel(
                    course: course,
                    activeLessonId: lesson?.id,
                    onSelect: onSelect,
                  ),
                ),
              ),
            Expanded(
              child: lesson == null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(WEAInsets.lg),
                        child: LearnerEmptyState(
                          icon: Icons.menu_book_outlined,
                          title: 'No lessons released yet',
                          message:
                              'The curriculum for this course is being '
                              'prepared. You will be notified when it opens.',
                          actionLabel: 'BACK TO COURSE',
                          onAction: () =>
                              context.go('/learner/courses/${course.id}'),
                        ),
                      ),
                    )
                  : LessonPage(course: course, lesson: lesson!),
            ),
          ],
        ),
      ),
    ],
  );
}

/// Course context and progress, plus the way back out of learning mode.
class _LearningTopBar extends StatelessWidget {
  const _LearningTopBar({
    required this.course,
    required this.showCurriculumButton,
    required this.onOpenCurriculum,
  });

  final LearnerCourse course;
  final bool showCurriculumButton;
  final VoidCallback onOpenCurriculum;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final compact = MediaQuery.sizeOf(context).width < 700;

    return Container(
      height: 68,
      padding: const EdgeInsets.symmetric(horizontal: WEAInsets.md),
      decoration: const BoxDecoration(
        color: WEAColors.background,
        border: Border(bottom: BorderSide(color: WEAColors.border)),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back to course',
            onPressed: () => context.go('/learner/courses/${course.id}'),
            icon: const Icon(Icons.arrow_back),
          ),
          if (showCurriculumButton)
            IconButton(
              tooltip: 'Course curriculum',
              onPressed: onOpenCurriculum,
              icon: const Icon(Icons.list_alt_outlined),
            ),
          const SizedBox(width: WEAInsets.xs),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  course.title,
                  style: theme.textTheme.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${course.completedLessons} of ${course.totalLessons} '
                  'lessons complete',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (!compact) ...[
            SizedBox(
              width: 160,
              child: LearnerProgressBar(value: course.progress),
            ),
            const SizedBox(width: WEAInsets.sm),
          ],
          Text(
            '${course.progressPercent}%',
            style: theme.textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}

class _CurriculumPanel extends StatelessWidget {
  const _CurriculumPanel({
    required this.course,
    required this.activeLessonId,
    required this.onSelect,
  });

  final LearnerCourse course;
  final String? activeLessonId;
  final ValueChanged<Lesson> onSelect;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.only(bottom: WEAInsets.lg),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            WEAInsets.md,
            WEAInsets.lg,
            WEAInsets.md,
            WEAInsets.xs,
          ),
          child: Text(
            'COURSE CURRICULUM',
            style: theme.textTheme.labelSmall?.copyWith(
              color: WEAColors.mutedText,
              letterSpacing: 1.5,
            ),
          ),
        ),
        CurriculumWidget(
          course: course,
          activeLessonId: activeLessonId,
          dense: true,
          onSelectLesson: onSelect,
        ),
      ],
    );
  }
}
