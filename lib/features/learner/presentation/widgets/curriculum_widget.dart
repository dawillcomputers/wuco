import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../domain/learner_course.dart';
import '../../domain/learner_enums.dart';

IconData iconForLessonType(LessonType type) => switch (type) {
  LessonType.video => Icons.play_circle_outline,
  LessonType.text => Icons.article_outlined,
  LessonType.pdf => Icons.picture_as_pdf_outlined,
  LessonType.presentation => Icons.slideshow_outlined,
  LessonType.audio => Icons.headphones_outlined,
  LessonType.externalResource => Icons.link_outlined,
  LessonType.quiz => Icons.quiz_outlined,
  LessonType.assignment => Icons.assignment_outlined,
  LessonType.caseStudy => Icons.cases_outlined,
  LessonType.liveSession => Icons.videocam_outlined,
};

/// Modules and lessons for a course.
///
/// State is shown by icon and text as well as colour: completed carries a
/// tick, the current lesson an arrow, and locked lessons a padlock plus an
/// explicit "Locked" label.
class CurriculumWidget extends StatelessWidget {
  const CurriculumWidget({
    super.key,
    required this.course,
    this.activeLessonId,
    this.onSelectLesson,
    this.dense = false,
  });

  final LearnerCourse course;
  final String? activeLessonId;
  final ValueChanged<Lesson>? onSelectLesson;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final module in course.modules) ...[
          Padding(
            padding: EdgeInsets.fromLTRB(
              WEAInsets.md,
              WEAInsets.md,
              WEAInsets.md,
              WEAInsets.xs,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MODULE ${module.number.toString().padLeft(2, '0')}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: WEAColors.accent,
                          letterSpacing: 1.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(module.title, style: theme.textTheme.titleMedium),
                    ],
                  ),
                ),
                Text(
                  '${module.completedLessons}/${module.lessons.length}',
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
          ),
          for (final lesson in module.lessons)
            _LessonRow(
              lesson: lesson,
              active: lesson.id == activeLessonId,
              dense: dense,
              onTap: lesson.state.isOpenable && onSelectLesson != null
                  ? () => onSelectLesson!(lesson)
                  : null,
            ),
          const SizedBox(height: WEAInsets.xs),
        ],
      ],
    );
  }
}

class _LessonRow extends StatelessWidget {
  const _LessonRow({
    required this.lesson,
    required this.active,
    required this.dense,
    this.onTap,
  });

  final Lesson lesson;
  final bool active;
  final bool dense;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locked = lesson.state == LessonState.locked;

    final (statusIcon, statusColour, statusLabel) = switch (lesson.state) {
      LessonState.completed => (
        Icons.check_circle,
        WEAColors.success,
        'Completed',
      ),
      LessonState.inProgress => (
        Icons.play_circle_fill,
        WEAColors.accent,
        'In progress',
      ),
      LessonState.available => (
        Icons.radio_button_unchecked,
        WEAColors.mutedText,
        'Not started',
      ),
      LessonState.locked => (Icons.lock_outline, WEAColors.mutedText, 'Locked'),
    };

    return Semantics(
      button: onTap != null,
      enabled: !locked,
      label: '${lesson.title}. $statusLabel.',
      child: InkWell(
        onTap: onTap,
        child: Opacity(
          opacity: locked ? .55 : 1,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: WEAInsets.md,
              vertical: dense ? 9 : 11,
            ),
            decoration: BoxDecoration(
              color: active ? WEAColors.accent.withValues(alpha: .08) : null,
              border: Border(
                left: BorderSide(
                  color: active ? WEAColors.accent : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(statusIcon, size: 17, color: statusColour),
                const SizedBox(width: WEAInsets.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lesson.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: WEAColors.primaryText,
                          fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        '${lesson.type.label} · ${lesson.durationMinutes} min'
                        '${locked ? ' · Locked' : ''}',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                if (lesson.bookmarked)
                  const Icon(
                    Icons.bookmark,
                    size: 15,
                    color: WEAColors.accentSoft,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
