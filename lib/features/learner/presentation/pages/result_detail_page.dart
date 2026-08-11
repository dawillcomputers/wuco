import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../application/learner_providers.dart';
import '../../domain/learner_records.dart';
import '../shell/learner_shell.dart';
import '../widgets/learner_detail_widgets.dart';
import '../widgets/learner_lists.dart';
import '../widgets/learner_page_header.dart';
import '../widgets/learner_progress.dart';
import '../widgets/learner_states.dart';

/// A single result, with faculty feedback where it has been given.
///
/// Only the signed-in learner's own results are reachable: the repository is
/// scoped to them and never accepts another learner's identifier.
class ResultDetailPage extends ConsumerWidget {
  const ResultDetailPage({super.key, required this.resultId});

  final String resultId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => LearnerPageBody(
    child: LearnerAsync(
      value: ref.watch(resultsProvider),
      onRetry: () => ref.invalidate(resultsProvider),
      loading: const LearnerCardSkeleton(count: 2, height: 180),
      data: (results) {
        final result = results.where((item) => item.id == resultId).firstOrNull;
        if (result == null) {
          return LearnerEmptyState(
            icon: Icons.search_off_outlined,
            title: 'Result not found',
            message:
                'This result is not one of yours, or the link is no longer '
                'valid.',
            actionLabel: 'BACK TO RESULTS',
            onAction: () => context.go('/learner/results'),
          );
        }
        return _ResultDetail(result: result);
      },
    ),
  );
}

class _ResultDetail extends StatelessWidget {
  const _ResultDetail({required this.result});

  final AssessmentResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LearnerPageHeader(
          eyebrow: 'Result',
          title: result.assessmentTitle,
          description: result.courseTitle,
          backRoute: '/learner/results',
          backLabel: 'Results',
          trailing: LearnerStatusChip.outcome(result.outcome),
        ),
        LearnerCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Wraps rather than a Row: on a narrow phone the headline score
              // and its supporting line belong on separate lines.
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.end,
                spacing: WEAInsets.sm,
                runSpacing: WEAInsets.xxs,
                children: [
                  Text(
                    '${result.percentageRounded}%',
                    style: theme.textTheme.displayMedium?.copyWith(
                      color: WEAColors.accent,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Text(
                      '${result.score.toStringAsFixed(0)} of '
                      '${result.maximumScore.toStringAsFixed(0)} marks',
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: WEAInsets.sm),
              LearnerProgressBar(value: result.percentage, height: 8),
              const SizedBox(height: WEAInsets.lg),
              LearnerFactGrid(
                facts: [
                  LearnerFact(
                    label: 'Grade',
                    value: result.grade,
                    icon: Icons.workspace_premium_outlined,
                  ),
                  LearnerFact(
                    label: 'Outcome',
                    value: result.outcome.label,
                    icon: Icons.flag_outlined,
                  ),
                  LearnerFact(
                    label: 'Published',
                    value: formatShortDate(result.date),
                    icon: Icons.event_outlined,
                  ),
                  LearnerFact(
                    label: 'Marked by',
                    value: result.markedBy ?? 'WEA faculty',
                    icon: Icons.person_outline,
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: WEAInsets.lg),
        LearnerPanel(
          title: 'Faculty feedback',
          child: Text(
            result.feedback ??
                'No written feedback was recorded for this assessment.',
            style: theme.textTheme.bodyLarge,
          ),
        ),
        const SizedBox(height: WEAInsets.lg),
        const LearnerLockedNote(
          message:
              'Scores, grades and outcomes are issued by WEA faculty and are '
              'not editable from your account.',
        ),
      ],
    );
  }
}
