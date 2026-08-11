import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../shared/components/wea_components.dart';
import '../../domain/learner_course.dart';
import '../../domain/learner_programme.dart';
import 'learner_progress.dart';
import 'learner_states.dart';

/// Course artwork with a graceful fallback, so a failed image never leaves a
/// hole in the layout.
class LearnerCourseImage extends StatelessWidget {
  const LearnerCourseImage({
    super.key,
    required this.url,
    required this.aspectRatio,
    this.zoomed = false,
  });

  final String url;
  final double aspectRatio;
  final bool zoomed;

  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: aspectRatio,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(WEAInsets.smallRadius),
      child: AnimatedScale(
        scale: zoomed ? 1.04 : 1,
        duration: const Duration(milliseconds: 260),
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => const ColoredBox(
            color: WEAColors.elevated,
            child: Center(
              child: Icon(
                Icons.school_outlined,
                color: WEAColors.mutedText,
                size: 22,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// The dashboard's primary call to action: resume the most recent course.
class ContinueLearningCard extends StatelessWidget {
  const ContinueLearningCard({super.key, required this.course});

  final LearnerCourse course;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lesson = course.currentLesson;
    final narrow = MediaQuery.sizeOf(context).width < 760;

    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          course.category.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: WEAColors.accent,
            letterSpacing: 1.3,
          ),
        ),
        const SizedBox(height: WEAInsets.xs),
        Text(course.title, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text(course.faculty, style: theme.textTheme.bodySmall),
        const SizedBox(height: WEAInsets.md),
        LearnerProgressSummary(
          percent: course.progressPercent,
          completedLessons: course.completedLessons,
          totalLessons: course.totalLessons,
          remainingMinutes: course.remainingMinutes,
        ),
        if (lesson != null) ...[
          const SizedBox(height: WEAInsets.md),
          Container(
            padding: const EdgeInsets.all(WEAInsets.sm),
            decoration: BoxDecoration(
              color: WEAColors.surfaceMuted,
              borderRadius: BorderRadius.circular(WEAInsets.smallRadius),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.play_circle_outline,
                  size: 18,
                  color: WEAColors.accent,
                ),
                const SizedBox(width: WEAInsets.xs),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Up next', style: theme.textTheme.labelSmall),
                      Text(
                        lesson.title,
                        style: theme.textTheme.bodyMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: WEAInsets.md),
        SizedBox(
          height: 46,
          child: ElevatedButton.icon(
            onPressed: () => context.go('/learner/courses/${course.id}/learn'),
            icon: const Icon(Icons.play_arrow_rounded, size: 18),
            label: const Text('CONTINUE LEARNING'),
          ),
        ),
      ],
    );

    return LearnerCard(
      child: narrow
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LearnerCourseImage(url: course.imageUrl, aspectRatio: 16 / 8),
                const SizedBox(height: WEAInsets.md),
                details,
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 260,
                  child: LearnerCourseImage(
                    url: course.imageUrl,
                    aspectRatio: 4 / 3,
                  ),
                ),
                const SizedBox(width: WEAInsets.lg),
                Expanded(child: details),
              ],
            ),
    );
  }
}

class LearnerProgrammeCard extends StatelessWidget {
  const LearnerProgrammeCard({super.key, required this.programme});

  final LearnerProgramme programme;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LearnerCard(
      onTap: () => context.go('/learner/programmes/${programme.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LearnerCourseImage(url: programme.imageUrl, aspectRatio: 16 / 7),
          const SizedBox(height: WEAInsets.md),
          Row(
            children: [
              Expanded(
                child: Text(
                  programme.category.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: WEAColors.accent,
                    letterSpacing: 1.3,
                  ),
                ),
              ),
              LearnerStatusChip.programme(programme.status),
            ],
          ),
          const SizedBox(height: WEAInsets.xs),
          Text(
            programme.title,
            style: theme.textTheme.titleLarge,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: WEAInsets.xs),
          Text(
            '${programme.durationLabel} · ${programme.deliveryMode}',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: WEAInsets.sm),
          Text(
            programme.summary,
            style: theme.textTheme.bodyMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: WEAInsets.md),
          WEATextButton(
            label: 'VIEW PROGRAMME  →',
            onPressed: () => context.go('/learner/programmes/${programme.id}'),
          ),
        ],
      ),
    );
  }
}

/// Course card with the subtle hover treatment the brief asks for: a small
/// lift, a border shift and a slight image zoom — nothing more.
class LearnerCourseCard extends StatefulWidget {
  const LearnerCourseCard({super.key, required this.course});

  final LearnerCourse course;

  @override
  State<LearnerCourseCard> createState() => _LearnerCourseCardState();
}

class _LearnerCourseCardState extends State<LearnerCourseCard> {
  var _hovering = false;

  @override
  Widget build(BuildContext context) {
    final course = widget.course;
    final theme = Theme.of(context);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      // Keyboard-reachable, with focus reusing the hover treatment so the card
      // shows where you are when tabbing through the grid.
      child: InkWell(
        onTap: () => context.go('/learner/courses/${course.id}'),
        onFocusChange: (focused) => setState(() => _hovering = focused),
        borderRadius: BorderRadius.circular(WEAInsets.radius),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, _hovering ? -3 : 0, 0),
          decoration: BoxDecoration(
            color: WEAColors.card,
            border: Border.all(
              color: _hovering ? WEAColors.accent : WEAColors.border,
            ),
            borderRadius: BorderRadius.circular(WEAInsets.radius),
            boxShadow: _hovering
                ? [
                    BoxShadow(
                      color: WEAColors.navy.withValues(alpha: .10),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          padding: const EdgeInsets.all(WEAInsets.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LearnerCourseImage(
                url: course.imageUrl,
                aspectRatio: 16 / 8,
                zoomed: _hovering,
              ),
              const SizedBox(height: WEAInsets.sm),
              Text(
                course.category.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: WEAColors.accent,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                course.title,
                style: theme.textTheme.titleMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                '${course.faculty} · ${course.durationLabel}',
                style: theme.textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: WEAInsets.sm),
              LearnerProgressBar(value: course.progress),
              const SizedBox(height: WEAInsets.xs),
              Row(
                children: [
                  Text(
                    '${course.progressPercent}%',
                    style: theme.textTheme.labelMedium,
                  ),
                  const Spacer(),
                  LearnerStatusChip.course(course.status),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
