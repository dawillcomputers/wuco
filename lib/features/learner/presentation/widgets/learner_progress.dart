import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import '../../domain/learner_enums.dart';
import 'learner_states.dart';

/// Slim progress bar. Deliberately restrained — progress is information, not
/// decoration.
class LearnerProgressBar extends StatelessWidget {
  const LearnerProgressBar({
    super.key,
    required this.value,
    this.height = 6,
    this.colour,
  });

  final double value;
  final double height;
  final Color? colour;

  @override
  Widget build(BuildContext context) => Semantics(
    value: '${(value * 100).round()} percent complete',
    child: ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.clamp(0, 1)),
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeOutCubic,
        builder: (context, animated, _) => LinearProgressIndicator(
          value: animated,
          minHeight: height,
          backgroundColor: WEAColors.elevated,
          valueColor: AlwaysStoppedAnimation(colour ?? WEAColors.accent),
        ),
      ),
    ),
  );
}

/// Progress with its supporting numbers, as the brief specifies.
class LearnerProgressSummary extends StatelessWidget {
  const LearnerProgressSummary({
    super.key,
    required this.percent,
    required this.completedLessons,
    required this.totalLessons,
    required this.remainingMinutes,
  });

  final int percent;
  final int completedLessons;
  final int totalLessons;
  final int remainingMinutes;

  static String formatDuration(int minutes) {
    if (minutes <= 0) return 'Complete';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    if (hours == 0) return '${rest}m';
    return rest == 0 ? '${hours}h' : '${hours}h ${rest}m';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('$percent%', style: theme.textTheme.titleMedium),
            const Spacer(),
            Text(
              '$completedLessons of $totalLessons lessons',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: WEAInsets.xs),
        LearnerProgressBar(value: totalLessons == 0 ? 0 : percent / 100),
        const SizedBox(height: WEAInsets.xs),
        Text(
          remainingMinutes <= 0
              ? 'All lessons complete'
              : 'Approximately ${formatDuration(remainingMinutes)} remaining',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// Status pill. Always pairs an icon with the label so meaning does not rely
/// on colour.
class LearnerStatusChip extends StatelessWidget {
  const LearnerStatusChip({
    super.key,
    required this.label,
    required this.tone,
    required this.icon,
  });

  factory LearnerStatusChip.programme(ProgrammeStatus status) {
    final (tone, icon) = switch (status) {
      ProgrammeStatus.notStarted => (WEAColors.mutedText, Icons.schedule),
      ProgrammeStatus.inProgress => (WEAColors.accent, Icons.play_arrow_rounded),
      ProgrammeStatus.awaitingAssessment => (
        WEAColors.warning,
        Icons.hourglass_empty,
      ),
      ProgrammeStatus.certificateAvailable => (
        WEAColors.success,
        Icons.workspace_premium_outlined,
      ),
      ProgrammeStatus.completed => (WEAColors.success, Icons.check_circle_outline),
      ProgrammeStatus.expired => (WEAColors.mutedText, Icons.event_busy_outlined),
      ProgrammeStatus.suspended => (WEAColors.error, Icons.block_outlined),
    };
    return LearnerStatusChip(label: status.label, tone: tone, icon: icon);
  }

  factory LearnerStatusChip.course(CourseStatus status) {
    final (tone, icon) = switch (status) {
      CourseStatus.notStarted => (WEAColors.mutedText, Icons.schedule),
      CourseStatus.inProgress => (WEAColors.accent, Icons.play_arrow_rounded),
      CourseStatus.assessmentPending => (
        WEAColors.warning,
        Icons.assignment_outlined,
      ),
      CourseStatus.certificateEligible => (
        WEAColors.success,
        Icons.workspace_premium_outlined,
      ),
      CourseStatus.completed => (WEAColors.success, Icons.check_circle_outline),
    };
    return LearnerStatusChip(label: status.label, tone: tone, icon: icon);
  }

  factory LearnerStatusChip.assessment(AssessmentStatus status) {
    final (tone, icon) = switch (status) {
      AssessmentStatus.upcoming => (WEAColors.mutedText, Icons.schedule),
      AssessmentStatus.available => (WEAColors.accent, Icons.edit_outlined),
      AssessmentStatus.submitted => (WEAColors.accent, Icons.outbox_outlined),
      AssessmentStatus.marking => (WEAColors.warning, Icons.hourglass_empty),
      AssessmentStatus.completed => (
        WEAColors.success,
        Icons.check_circle_outline,
      ),
      AssessmentStatus.missed => (WEAColors.error, Icons.event_busy_outlined),
    };
    return LearnerStatusChip(label: status.label, tone: tone, icon: icon);
  }

  factory LearnerStatusChip.outcome(ResultOutcome outcome) {
    final (tone, icon) = switch (outcome) {
      ResultOutcome.passed => (WEAColors.success, Icons.check_circle_outline),
      ResultOutcome.failed => (WEAColors.error, Icons.cancel_outlined),
      ResultOutcome.pending => (WEAColors.warning, Icons.hourglass_empty),
    };
    return LearnerStatusChip(label: outcome.label, tone: tone, icon: icon);
  }

  final String label;
  final Color tone;
  final IconData icon;

  /// A chip usually sits beside flexible content as an inflexible child, which
  /// means the parent row hands it unbounded width. Capping it here keeps a
  /// long status from squeezing its neighbour to nothing.
  static const maxWidth = 190.0;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(maxWidth: maxWidth),
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: tone.withValues(alpha: .10),
      border: Border.all(color: tone.withValues(alpha: .34)),
      borderRadius: BorderRadius.circular(99),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: tone),
        const SizedBox(width: 5),
        // Flexible so a long status ("Certificate available") shortens rather
        // than pushing the chip past the card it sits in.
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: tone),
          ),
        ),
      ],
    ),
  );
}

/// Compact headline metric for the dashboard.
class LearnerStatCard extends StatelessWidget {
  const LearnerStatCard({
    super.key,
    required this.value,
    required this.label,
    required this.icon,
  });

  final String value;
  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LearnerCard(
      padding: const EdgeInsets.all(WEAInsets.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: WEAColors.accent),
          const SizedBox(height: WEAInsets.sm),
          Text(
            value,
            style: theme.textTheme.headlineMedium?.copyWith(height: 1.1),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: theme.textTheme.bodySmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
