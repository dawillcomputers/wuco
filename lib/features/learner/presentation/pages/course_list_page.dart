import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../../../shared/animations/wea_animations.dart';
import '../../application/learner_providers.dart';
import '../../domain/learner_enums.dart';
import '../shell/learner_shell.dart';
import '../widgets/bookmarked_lessons_panel.dart';
import '../widgets/learner_cards.dart';
import '../widgets/learner_page_header.dart';
import '../widgets/learner_states.dart';

/// Every course the learner is enrolled on, with filtering and search.
///
/// Filtering and matching live in [filteredCoursesProvider]; this page only
/// renders the outcome.
class CourseListPage extends ConsumerStatefulWidget {
  const CourseListPage({super.key});

  @override
  ConsumerState<CourseListPage> createState() => _CourseListPageState();
}

class _CourseListPageState extends ConsumerState<CourseListPage> {
  late final TextEditingController _search = TextEditingController(
    text: ref.read(courseQueryProvider),
  );

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final courses = ref.watch(filteredCoursesProvider);
    final filter = ref.watch(courseFilterProvider);
    final query = ref.watch(courseQueryProvider);

    return LearnerPageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const LearnerPageHeader(
            eyebrow: 'My courses',
            title: 'Your courses',
            description:
                'Everything you are enrolled on, filtered by where each course '
                'stands.',
          ),
          _CourseSearchField(controller: _search),
          const SizedBox(height: WEAInsets.sm),
          _FilterBar(selected: filter),
          const SizedBox(height: WEAInsets.lg),
          LearnerAsync(
            value: courses,
            onRetry: () => ref.invalidate(enrolledCoursesProvider),
            loading: const LearnerCardSkeleton(count: 3, height: 190),
            data: (items) => items.isEmpty
                ? _emptyState(filter: filter, query: query)
                : LearnerResponsiveGrid(
                    minItemWidth: 300,
                    children: [
                      for (var i = 0; i < items.length; i++)
                        WEAEntrance(
                          delay: Duration(milliseconds: 50 * i),
                          child: LearnerCourseCard(course: items[i]),
                        ),
                    ],
                  ),
          ),
          const BookmarkedLessonsPanel(),
        ],
      ),
    );
  }

  Widget _emptyState({required CourseFilter filter, required String query}) {
    final filtered = filter != CourseFilter.all || query.trim().isNotEmpty;
    if (filtered) {
      return LearnerEmptyState(
        icon: Icons.filter_alt_outlined,
        title: 'No courses match',
        message:
            'Nothing here matches the current filter. Try a different status '
            'or clear your search.',
        actionLabel: 'CLEAR FILTERS',
        onAction: () {
          _search.clear();
          ref.read(courseQueryProvider.notifier).set('');
          ref.read(courseFilterProvider.notifier).set(CourseFilter.all);
        },
      );
    }
    return LearnerEmptyState(
      icon: Icons.menu_book_outlined,
      title: 'No courses yet',
      message:
          'Once you are enrolled on a programme, its courses will appear here.',
      actionLabel: 'EXPLORE PROGRAMMES',
      onAction: () => context.go('/programmes'),
    );
  }
}

class _CourseSearchField extends ConsumerWidget {
  const _CourseSearchField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) => TextField(
    controller: controller,
    onChanged: (value) => ref.read(courseQueryProvider.notifier).set(value),
    textInputAction: TextInputAction.search,
    decoration: InputDecoration(
      hintText: 'Search your courses by title, subject or faculty',
      prefixIcon: const Icon(Icons.search, size: 20),
      suffixIcon: controller.text.isEmpty
          ? null
          : IconButton(
              tooltip: 'Clear search',
              icon: const Icon(Icons.close, size: 18),
              onPressed: () {
                controller.clear();
                ref.read(courseQueryProvider.notifier).set('');
              },
            ),
    ),
  );
}

/// Status filters. Wraps on narrow screens rather than scrolling horizontally,
/// so every option stays reachable.
class _FilterBar extends ConsumerWidget {
  const _FilterBar({required this.selected});

  final CourseFilter selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Wrap(
    spacing: WEAInsets.xs,
    runSpacing: WEAInsets.xs,
    children: [
      for (final filter in CourseFilter.values)
        ChoiceChip(
          label: Text(filter.label),
          selected: filter == selected,
          showCheckmark: false,
          onSelected: (_) =>
              ref.read(courseFilterProvider.notifier).set(filter),
          selectedColor: WEAColors.accent.withValues(alpha: .12),
          side: BorderSide(
            color: filter == selected ? WEAColors.accent : WEAColors.border,
          ),
          labelStyle: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: filter == selected
                ? WEAColors.accentDeep
                : WEAColors.secondaryText,
          ),
        ),
    ],
  );
}
