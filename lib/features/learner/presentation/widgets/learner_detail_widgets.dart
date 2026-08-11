import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_dimensions.dart';
import 'learner_states.dart';

/// A labelled fact. Used wherever a detail page lists programme, course or
/// certificate metadata, so the label/value rhythm is identical throughout.
class LearnerFact extends StatelessWidget {
  const LearnerFact({
    super.key,
    required this.label,
    required this.value,
    this.icon,
  });

  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: WEAColors.mutedText),
              const SizedBox(width: 5),
            ],
            Flexible(
              child: Text(
                label.toUpperCase(),
                style: theme.textTheme.labelSmall?.copyWith(
                  color: WEAColors.mutedText,
                  letterSpacing: 1.1,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: WEAColors.primaryText,
          ),
        ),
      ],
    );
  }
}

/// A wrapping row of [LearnerFact]s that reflows instead of overflowing.
class LearnerFactGrid extends StatelessWidget {
  const LearnerFactGrid({super.key, required this.facts, this.minWidth = 150});

  final List<LearnerFact> facts;
  final double minWidth;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const spacing = WEAInsets.lg;
      final columns = (constraints.maxWidth / minWidth).floor().clamp(1, 4);
      final width = (constraints.maxWidth - spacing * (columns - 1)) / columns;
      return Wrap(
        spacing: spacing,
        runSpacing: WEAInsets.md,
        children: [
          for (final fact in facts) SizedBox(width: width, child: fact),
        ],
      );
    },
  );
}

/// Bulleted list used for learning objectives and outcomes.
class LearnerBulletList extends StatelessWidget {
  const LearnerBulletList({super.key, required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: WEAInsets.xs),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 3),
                  child: Icon(
                    Icons.check_circle_outline,
                    size: 16,
                    color: WEAColors.accent,
                  ),
                ),
                const SizedBox(width: WEAInsets.xs),
                Expanded(child: Text(item, style: theme.textTheme.bodyMedium)),
              ],
            ),
          ),
      ],
    );
  }
}

/// A titled panel. Detail pages are built from a stack of these.
class LearnerPanel extends StatelessWidget {
  const LearnerPanel({
    super.key,
    required this.title,
    required this.child,
    this.action,
    this.padding = const EdgeInsets.all(WEAInsets.lg),
  });

  final String title;
  final Widget child;
  final Widget? action;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LearnerCard(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: theme.textTheme.titleLarge)),
              ?action,
            ],
          ),
          const SizedBox(height: WEAInsets.md),
          child,
        ],
      ),
    );
  }
}

/// A read-only value the learner cannot change, shown with the reason why.
/// Used for grades, certificate numbers and CPD points.
class LearnerLockedNote extends StatelessWidget {
  const LearnerLockedNote({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(WEAInsets.sm),
    decoration: BoxDecoration(
      color: WEAColors.surfaceMuted,
      borderRadius: BorderRadius.circular(WEAInsets.smallRadius),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.lock_outline, size: 15, color: WEAColors.mutedText),
        const SizedBox(width: WEAInsets.xs),
        Expanded(
          child: Text(
            message,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    ),
  );
}
