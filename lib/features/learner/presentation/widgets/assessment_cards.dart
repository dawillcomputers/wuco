import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../domain/learner_enums.dart';
import '../../domain/learner_records.dart';
import 'learner_lists.dart';
import 'learner_progress.dart';
import 'learner_states.dart';

/// One assessment in the learner's schedule.
///
/// Deadlines are stated plainly — a due date and a remaining count — without
/// alarm colouring, per the module brief.
class AssessmentCard extends StatelessWidget {
  const AssessmentCard({super.key, required this.assessment});

  final Assessment assessment;

  String get _dueLabel {
    final due = assessment.dueDate;
    if (due == null) return 'No deadline set';
    final days = assessment.daysRemaining ?? 0;
    final date = formatShortDate(due);
    return switch (days) {
      < 0 => 'Closed $date',
      0 => 'Due today · $date',
      1 => 'Due tomorrow · $date',
      _ => '$days days remaining · $date',
    };
  }

  bool get _isOpen =>
      assessment.status == AssessmentStatus.available &&
      assessment.attemptsRemaining > 0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LearnerCard(
      padding: const EdgeInsets.all(WEAInsets.md),
      onTap: () => context.go('/learner/assessments/${assessment.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  assessment.type.label.toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: WEAColors.accent,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              LearnerStatusChip.assessment(assessment.status),
            ],
          ),
          const SizedBox(height: WEAInsets.xs),
          Text(
            assessment.title,
            style: theme.textTheme.titleMedium,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            assessment.courseTitle,
            style: theme.textTheme.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: WEAInsets.sm),
          Wrap(
            spacing: WEAInsets.md,
            runSpacing: 4,
            children: [
              _Meta(icon: Icons.event_outlined, label: _dueLabel),
              _Meta(
                icon: Icons.timer_outlined,
                label: '${assessment.durationMinutes} min',
              ),
              _Meta(
                icon: Icons.replay_outlined,
                label: '${assessment.attemptsRemaining} of '
                    '${assessment.attemptsAllowed} attempts left',
              ),
            ],
          ),
          const SizedBox(height: WEAInsets.md),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              onPressed: () =>
                  context.go('/learner/assessments/${assessment.id}'),
              child: Text(_isOpen ? 'OPEN ASSESSMENT' : 'VIEW DETAILS'),
            ),
          ),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 13, color: WEAColors.mutedText),
      const SizedBox(width: 5),
      // The wrap that holds these gives each line the card's width; a long
      // due-date phrase must fold inside its own line, not overrun it.
      Flexible(
        child: Text(label, style: Theme.of(context).textTheme.bodySmall),
      ),
    ],
  );
}

/// A single published result. Rendered as a card on narrow screens and as a
/// table row on wide ones, so results stay scannable without side-scrolling.
class ResultRow extends StatelessWidget {
  const ResultRow({super.key, required this.result, required this.asRow});

  final AssessmentResult result;
  final bool asRow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final score =
        '${result.score.toStringAsFixed(0)}/'
        '${result.maximumScore.toStringAsFixed(0)}';

    void open() => context.go('/learner/results/${result.id}');

    if (!asRow) {
      return LearnerCard(
        padding: const EdgeInsets.all(WEAInsets.md),
        onTap: open,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(result.assessmentTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 2),
            Text(result.courseTitle, style: theme.textTheme.bodySmall),
            const SizedBox(height: WEAInsets.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    '$score  ·  ${result.percentageRounded}%',
                    style: theme.textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: WEAInsets.xs),
                Flexible(child: LearnerStatusChip.outcome(result.outcome)),
              ],
            ),
            const SizedBox(height: WEAInsets.xs),
            Text(
              '${result.grade} · ${formatShortDate(result.date)}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      );
    }

    return InkWell(
      onTap: open,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: WEAInsets.md,
          vertical: WEAInsets.sm,
        ),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.assessmentTitle,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: WEAColors.primaryText,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    result.courseTitle,
                    style: theme.textTheme.bodySmall,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                formatShortDate(result.date),
                style: theme.textTheme.bodyMedium,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(
                '$score (${result.percentageRounded}%)',
                style: theme.textTheme.bodyMedium,
              ),
            ),
            Expanded(
              flex: 2,
              child: Text(result.grade, style: theme.textTheme.bodyMedium),
            ),
            LearnerStatusChip.outcome(result.outcome),
          ],
        ),
      ),
    );
  }
}

/// Column captions for the wide-screen results table.
class ResultTableHeader extends StatelessWidget {
  const ResultTableHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
      color: WEAColors.mutedText,
      letterSpacing: 1.1,
    );
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: WEAInsets.md,
        vertical: WEAInsets.sm,
      ),
      decoration: const BoxDecoration(
        color: WEAColors.surfaceMuted,
        border: Border(bottom: BorderSide(color: WEAColors.border)),
      ),
      child: Row(
        children: [
          Expanded(flex: 4, child: Text('ASSESSMENT', style: style)),
          Expanded(flex: 2, child: Text('DATE', style: style)),
          Expanded(flex: 2, child: Text('SCORE', style: style)),
          Expanded(flex: 2, child: Text('GRADE', style: style)),
          Text('STATUS', style: style),
        ],
      ),
    );
  }
}
