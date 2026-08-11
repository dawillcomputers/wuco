import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../application/learner_providers.dart';
import '../../domain/learner_records.dart';
import '../shell/learner_shell.dart';
import '../widgets/credential_cards.dart';
import '../widgets/learner_detail_widgets.dart';
import '../widgets/learner_page_header.dart';
import '../widgets/learner_progress.dart';
import '../widgets/learner_states.dart';

/// Continuing professional development: points earned, and progress towards
/// the learner's own annual goal.
class CpdPage extends ConsumerWidget {
  const CpdPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => LearnerPageBody(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const LearnerPageHeader(
          eyebrow: 'CPD',
          title: 'Continuing professional development',
          description:
              'Points awarded for the learning you complete with WEA, tracked '
              'against the annual goal you set.',
        ),
        LearnerAsync(
          value: ref.watch(cpdSummaryProvider),
          onRetry: () => ref.invalidate(cpdSummaryProvider),
          loading: const LearnerCardSkeleton(count: 2, height: 180),
          data: (summary) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _CpdSummaryCard(summary: summary),
              const SizedBox(height: WEAInsets.lg),
              LearnerPanel(
                title: 'CPD history',
                child: summary.records.isEmpty
                    ? const Text(
                        'No CPD points have been awarded yet. Points are added '
                        'as you complete courses and assessments.',
                      )
                    : Column(
                        children: [
                          for (var i = 0; i < summary.records.length; i++)
                            CpdRecordTile(
                              record: summary.records[i],
                              last: i == summary.records.length - 1,
                            ),
                        ],
                      ),
              ),
              const SizedBox(height: WEAInsets.lg),
              const LearnerLockedNote(
                message:
                    'CPD points are awarded by WEA. You can set your own '
                    'annual goal, but not the points themselves.',
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _CpdSummaryCard extends ConsumerWidget {
  const _CpdSummaryCard({required this.summary});

  final CpdSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final narrow = MediaQuery.sizeOf(context).width < 760;

    final headline = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${summary.year} CPD YEAR',
          style: theme.textTheme.labelSmall?.copyWith(
            color: WEAColors.accent,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: WEAInsets.xs),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.end,
          spacing: 6,
          runSpacing: WEAInsets.xxs,
          children: [
            Text(
              '${summary.pointsEarned}',
              style: theme.textTheme.displayMedium?.copyWith(
                color: WEAColors.navy,
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Text(
                'of ${summary.pointsTarget} points',
                style: theme.textTheme.bodyLarge,
              ),
            ),
          ],
        ),
        const SizedBox(height: WEAInsets.sm),
        LearnerProgressBar(value: summary.progress, height: 8),
        const SizedBox(height: WEAInsets.xs),
        Text(
          summary.pointsRemaining == 0
              ? 'You have met your goal for this year.'
              : '${summary.pointsRemaining} points remaining to reach your '
                    'goal.',
          style: theme.textTheme.bodyMedium,
        ),
      ],
    );

    final target = _TargetControl(current: summary.pointsTarget);

    return LearnerCard(
      child: narrow
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                headline,
                const SizedBox(height: WEAInsets.lg),
                target,
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: headline),
                const SizedBox(width: WEAInsets.xl),
                SizedBox(width: 230, child: target),
              ],
            ),
    );
  }
}

/// The learner's personal annual goal. Configurable rather than fixed, since
/// accrediting bodies differ.
class _TargetControl extends ConsumerWidget {
  const _TargetControl({required this.current});

  final int current;

  static const _options = [20, 30, 40, 60, 80, 100];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    // A goal outside the presets (set elsewhere) still needs to be selectable.
    final options = {..._options, current}.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Annual goal', style: theme.textTheme.titleMedium),
        const SizedBox(height: WEAInsets.xs),
        DropdownButtonFormField<int>(
          initialValue: current,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'CPD points per year',
          ),
          items: [
            for (final option in options)
              DropdownMenuItem(value: option, child: Text('$option points')),
          ],
          onChanged: (value) => value == null
              ? null
              : ref.read(learnerActionsProvider).setCpdTarget(value),
        ),
        const SizedBox(height: WEAInsets.xs),
        Text(
          'Set this to match the requirement of your professional body.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}
