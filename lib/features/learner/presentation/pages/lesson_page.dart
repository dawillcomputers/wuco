import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../application/learner_providers.dart';
import '../../domain/learner_course.dart';
import '../../domain/learner_enums.dart';
import '../widgets/curriculum_widget.dart';
import '../widgets/learner_detail_widgets.dart';
import '../widgets/lesson_notes_panel.dart';
import '../widgets/lesson_player.dart';

/// The content pane of the learning interface: one lesson, its material, and
/// the controls for finishing it and moving on.
class LessonPage extends ConsumerStatefulWidget {
  const LessonPage({super.key, required this.course, required this.lesson});

  final LearnerCourse course;
  final Lesson lesson;

  @override
  ConsumerState<LessonPage> createState() => _LessonPageState();
}

class _LessonPageState extends ConsumerState<LessonPage>
    with SingleTickerProviderStateMixin {
  late LessonPlaybackController _playback;
  var _completing = false;

  bool get _isTimedMedia =>
      widget.lesson.type == LessonType.video ||
      widget.lesson.type == LessonType.audio;

  @override
  void initState() {
    super.initState();
    _playback = _newController();
  }

  @override
  void didUpdateWidget(covariant LessonPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A different lesson means a fresh transport; the old watched position
    // must not carry over and satisfy the completion criteria by accident.
    if (oldWidget.lesson.id != widget.lesson.id) {
      _playback.dispose();
      _playback = _newController();
    }
  }

  LessonPlaybackController _newController() => LessonPlaybackController(
    duration: Duration(minutes: widget.lesson.durationMinutes),
    vsync: this,
  );

  @override
  void dispose() {
    _playback.dispose();
    super.dispose();
  }

  /// Ordered lessons across the whole course, for previous/next.
  List<Lesson> get _flat => widget.course.lessons;
  int get _index => _flat.indexWhere((l) => l.id == widget.lesson.id);

  Lesson? get _previous => _index > 0 ? _flat[_index - 1] : null;
  Lesson? get _next =>
      _index >= 0 && _index + 1 < _flat.length ? _flat[_index + 1] : null;

  Future<void> _markComplete() async {
    setState(() => _completing = true);
    await ref
        .read(learnerActionsProvider)
        .completeLesson(
          courseId: widget.course.id,
          lessonId: widget.lesson.id,
        );
    if (!mounted) return;
    setState(() => _completing = false);
    final next = _next;
    if (next != null) {
      context.go(
        '/learner/courses/${widget.course.id}/lessons/${next.id}',
      );
    }
  }

  void _openFullscreen() {
    showDialog<void>(
      context: context,
      barrierColor: WEAColors.navyDeep,
      builder: (context) => Dialog.fullscreen(
        backgroundColor: WEAColors.navyDeep,
        child: Stack(
          children: [
            Center(
              child: LessonPlayer(
                lesson: widget.lesson,
                posterUrl: widget.course.imageUrl,
                controller: _playback,
                fullscreen: true,
                onRequestFullscreen: () => Navigator.of(context).pop(),
              ),
            ),
            Positioned(
              right: WEAInsets.sm,
              top: WEAInsets.sm,
              child: IconButton(
                tooltip: 'Close fullscreen',
                color: WEAColors.offWhite,
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lesson = widget.lesson;
    final theme = Theme.of(context);

    return SingleChildScrollView(
      padding: EdgeInsets.all(
        MediaQuery.sizeOf(context).width < 600 ? WEAInsets.md : WEAInsets.lg,
      ),
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 860),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_isTimedMedia)
                LessonPlayer(
                  lesson: lesson,
                  posterUrl: widget.course.imageUrl,
                  controller: _playback,
                  onRequestFullscreen: _openFullscreen,
                )
              else
                LessonStaticSurface(
                  type: lesson.type,
                  posterUrl: widget.course.imageUrl,
                ),
              const SizedBox(height: WEAInsets.lg),
              _LessonHeading(
                course: widget.course,
                lesson: lesson,
                onToggleBookmark: () => ref
                    .read(learnerActionsProvider)
                    .toggleBookmark(
                      courseId: widget.course.id,
                      lessonId: lesson.id,
                      bookmarked: !lesson.bookmarked,
                    ),
              ),
              const SizedBox(height: WEAInsets.md),
              _CompletionBar(
                lesson: lesson,
                playback: _playback,
                timed: _isTimedMedia,
                busy: _completing,
                onComplete: _markComplete,
              ),
              const SizedBox(height: WEAInsets.lg),
              if (lesson.description.isNotEmpty) ...[
                Text(lesson.description, style: theme.textTheme.bodyLarge),
                const SizedBox(height: WEAInsets.md),
              ],
              if (lesson.body != null) ...[
                Text(lesson.body!, style: theme.textTheme.bodyLarge),
                const SizedBox(height: WEAInsets.lg),
              ],
              if (lesson.objectives.isNotEmpty) ...[
                LearnerPanel(
                  title: 'Learning objectives',
                  child: LearnerBulletList(items: lesson.objectives),
                ),
                const SizedBox(height: WEAInsets.lg),
              ],
              if (lesson.resources.isNotEmpty) ...[
                LearnerPanel(
                  title: 'Resources',
                  child: Column(
                    children: [
                      for (final resource in lesson.resources)
                        Padding(
                          padding: const EdgeInsets.only(bottom: WEAInsets.xs),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.description_outlined,
                                size: 17,
                              ),
                              const SizedBox(width: WEAInsets.xs),
                              Expanded(
                                child: Text(
                                  resource.title,
                                  style: theme.textTheme.bodyLarge,
                                ),
                              ),
                              Text(
                                resource.kind,
                                style: theme.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: WEAInsets.lg),
              ],
              LessonNotesPanel(
                courseId: widget.course.id,
                lessonId: lesson.id,
              ),
              const SizedBox(height: WEAInsets.lg),
              const _DiscussionPlaceholder(),
              const SizedBox(height: WEAInsets.xl),
              _LessonNavigation(
                courseId: widget.course.id,
                previous: _previous,
                next: _next,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LessonHeading extends StatelessWidget {
  const _LessonHeading({
    required this.course,
    required this.lesson,
    required this.onToggleBookmark,
  });

  final LearnerCourse course;
  final Lesson lesson;
  final VoidCallback onToggleBookmark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final module = course.moduleOf(lesson);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                module == null
                    ? lesson.type.label.toUpperCase()
                    : 'MODULE ${module.number.toString().padLeft(2, '0')} · '
                          '${module.title.toUpperCase()}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: WEAColors.accent,
                  letterSpacing: 1.3,
                ),
              ),
              const SizedBox(height: WEAInsets.xs),
              Text(lesson.title, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    iconForLessonType(lesson.type),
                    size: 14,
                    color: WEAColors.mutedText,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '${lesson.type.label} · ${lesson.durationMinutes} minutes',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: lesson.bookmarked ? 'Remove bookmark' : 'Bookmark lesson',
          onPressed: onToggleBookmark,
          icon: Icon(
            lesson.bookmarked ? Icons.bookmark : Icons.bookmark_border,
            color: lesson.bookmarked ? WEAColors.accent : null,
          ),
        ),
      ],
    );
  }
}

/// Completion is earned, not granted on open: for timed media the button stays
/// disabled until the lesson has effectively been watched through.
class _CompletionBar extends StatelessWidget {
  const _CompletionBar({
    required this.lesson,
    required this.playback,
    required this.timed,
    required this.busy,
    required this.onComplete,
  });

  final Lesson lesson;
  final LessonPlaybackController playback;
  final bool timed;
  final bool busy;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (lesson.isComplete) {
      return Container(
        padding: const EdgeInsets.all(WEAInsets.sm),
        decoration: BoxDecoration(
          color: WEAColors.success.withValues(alpha: .08),
          border: Border.all(color: WEAColors.success.withValues(alpha: .32)),
          borderRadius: BorderRadius.circular(WEAInsets.smallRadius),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.check_circle_outline,
              size: 18,
              color: WEAColors.success,
            ),
            const SizedBox(width: WEAInsets.xs),
            Expanded(
              child: Text(
                'You completed this lesson.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      );
    }

    return ListenableBuilder(
      listenable: playback,
      builder: (context, _) {
        final ready = !timed || playback.meetsCompletionCriteria;
        return Wrap(
          spacing: WEAInsets.sm,
          runSpacing: WEAInsets.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              height: 46,
              child: ElevatedButton.icon(
                onPressed: ready && !busy ? onComplete : null,
                icon: busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check, size: 18),
                label: Text(busy ? 'SAVING…' : 'MARK AS COMPLETE'),
              ),
            ),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Text(
                ready
                    ? 'Marking this complete updates your course and programme '
                          'progress.'
                    : 'Available once you have watched the lesson through '
                          '(${(playback.watchedFraction * 100).round()}% so far).',
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Reserved space for cohort discussion, which arrives with a later module.
class _DiscussionPlaceholder extends StatelessWidget {
  const _DiscussionPlaceholder();

  @override
  Widget build(BuildContext context) => LearnerPanel(
    title: 'Discussion',
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.forum_outlined,
          size: 18,
          color: WEAColors.mutedText,
        ),
        const SizedBox(width: WEAInsets.sm),
        Expanded(
          child: Text(
            'Cohort discussion for this lesson is being prepared. You will be '
            'able to raise questions with faculty and fellow executives here.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    ),
  );
}

/// Previous/next, honouring the unlock rules and saying why when locked.
class _LessonNavigation extends StatelessWidget {
  const _LessonNavigation({
    required this.courseId,
    required this.previous,
    required this.next,
  });

  final String courseId;
  final Lesson? previous;
  final Lesson? next;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final nextLocked = next != null && !next!.state.isOpenable;

    final previousButton = OutlinedButton.icon(
      onPressed: previous == null
          ? null
          : () => context.go(
              '/learner/courses/$courseId/lessons/${previous!.id}',
            ),
      icon: const Icon(Icons.arrow_back, size: 16),
      label: const Text('PREVIOUS'),
    );
    final nextButton = OutlinedButton.icon(
      onPressed: next == null || nextLocked
          ? null
          : () =>
                context.go('/learner/courses/$courseId/lessons/${next!.id}'),
      iconAlignment: IconAlignment.end,
      icon: const Icon(Icons.arrow_forward, size: 16),
      label: const Text('NEXT LESSON'),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(),
        const SizedBox(height: WEAInsets.md),
        // Side by side where there is room; stacked and full width on a phone,
        // where two half-width buttons would clip their own labels.
        LayoutBuilder(
          builder: (context, constraints) => constraints.maxWidth < 420
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    nextButton,
                    const SizedBox(height: WEAInsets.xs),
                    previousButton,
                  ],
                )
              : Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: previousButton,
                      ),
                    ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: nextButton,
                      ),
                    ),
                  ],
                ),
        ),
        if (nextLocked) ...[
          const SizedBox(height: WEAInsets.sm),
          Text(
            'The next lesson unlocks once you complete this one.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ] else if (next == null) ...[
          const SizedBox(height: WEAInsets.sm),
          Text(
            'This is the final lesson in the course.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}
