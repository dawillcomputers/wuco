import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../domain/learner_course.dart';
import '../../domain/learner_enums.dart';
import 'learner_progress.dart';

/// A course as it appears inside a programme: numbered, with its own progress
/// and a single clear action.
class ProgrammeCourseRow extends StatefulWidget {
  const ProgrammeCourseRow({
    super.key,
    required this.course,
    required this.last,
  });

  final LearnerCourse course;
  final bool last;

  @override
  State<ProgrammeCourseRow> createState() => _ProgrammeCourseRowState();
}

class _ProgrammeCourseRowState extends State<ProgrammeCourseRow> {
  var _hovering = false;

  String get _actionLabel => switch (widget.course.status) {
    CourseStatus.notStarted => 'START',
    CourseStatus.completed => 'REVIEW',
    _ => 'CONTINUE',
  };

  @override
  Widget build(BuildContext context) {
    final course = widget.course;
    final theme = Theme.of(context);
    final narrow = MediaQuery.sizeOf(context).width < 720;

    final detail = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          course.title,
          style: theme.textTheme.titleMedium,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          course.summary,
          style: theme.textTheme.bodySmall,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: WEAInsets.xs),
        Wrap(
          spacing: WEAInsets.sm,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(course.faculty, style: theme.textTheme.bodySmall),
            Text('·', style: theme.textTheme.bodySmall),
            Text(course.durationLabel, style: theme.textTheme.bodySmall),
            LearnerStatusChip.course(course.status),
          ],
        ),
      ],
    );

    final progress = SizedBox(
      width: narrow ? double.infinity : 170,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${course.progressPercent}%',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          LearnerProgressBar(value: course.progress),
          const SizedBox(height: 4),
          Text(
            '${course.completedLessons} of ${course.totalLessons} lessons',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );

    final action = OutlinedButton(
      onPressed: () => context.go('/learner/courses/${course.id}'),
      child: Text(_actionLabel),
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(
          horizontal: WEAInsets.xs,
          vertical: WEAInsets.md,
        ),
        decoration: BoxDecoration(
          color: _hovering ? WEAColors.surfaceMuted : Colors.transparent,
          border: widget.last
              ? null
              : const Border(bottom: BorderSide(color: WEAColors.border)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 44,
              child: Text(
                course.number.toString().padLeft(2, '0'),
                style: theme.textTheme.titleLarge?.copyWith(
                  color: WEAColors.accent,
                ),
              ),
            ),
            Expanded(
              child: narrow
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        detail,
                        const SizedBox(height: WEAInsets.sm),
                        progress,
                        const SizedBox(height: WEAInsets.sm),
                        Align(alignment: Alignment.centerLeft, child: action),
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(child: detail),
                        const SizedBox(width: WEAInsets.md),
                        progress,
                        const SizedBox(width: WEAInsets.md),
                        action,
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
