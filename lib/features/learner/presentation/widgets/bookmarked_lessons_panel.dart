import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../application/learner_providers.dart';
import 'curriculum_widget.dart';
import 'learner_detail_widgets.dart';

/// Lessons the learner has bookmarked, across every course.
///
/// Renders nothing until there is at least one, so the page is not padded out
/// with an empty panel for learners who never bookmark.
class BookmarkedLessonsPanel extends ConsumerWidget {
  const BookmarkedLessonsPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final lessons = ref.watch(bookmarkedLessonsProvider).value ?? const [];
    if (lessons.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: WEAInsets.xl),
      child: LearnerPanel(
        title: 'Bookmarked lessons',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final lesson in lessons)
              InkWell(
                onTap: () => context.go(
                  '/learner/courses/${lesson.courseId}/lessons/${lesson.id}',
                ),
                borderRadius: BorderRadius.circular(WEAInsets.smallRadius),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: WEAInsets.xs),
                  child: Row(
                    children: [
                      Icon(
                        iconForLessonType(lesson.type),
                        size: 17,
                        color: WEAColors.accent,
                      ),
                      const SizedBox(width: WEAInsets.sm),
                      Expanded(
                        child: Text(
                          lesson.title,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: WEAColors.primaryText,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: WEAInsets.xs),
                      Text(
                        '${lesson.durationMinutes} min',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
